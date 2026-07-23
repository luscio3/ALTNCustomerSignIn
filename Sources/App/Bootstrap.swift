import Foundation

/// One-shot startup work: restore settings, drain offline queue if online,
/// refresh service catalog + consent templates for the saved franchise.
enum Bootstrap {
    @MainActor
    static func run(
        appState: AppState,
        connectivity: ConnectivityMonitor,
        offlineQueue: OfflineQueue
    ) async {
        connectivity.start()

        // When the network comes back: drain the offline queue AND re-fetch the
        // catalog. Without the re-fetch, an iPad that launched offline (e.g. app
        // auto-starts after a reboot before Wi-Fi joins) with no cached catalog
        // would show "Service catalog unavailable" forever despite being online.
        connectivity.onReconnect = { [weak appState] in
            Task {
                await offlineQueue.drain()
                if let appState, let f = appState.franchise, let l = appState.location {
                    await refreshBackingData(appState: appState, franchise: f, location: l)
                }
            }
        }

        // Pre-warm: refresh services + consent PDFs for the saved franchise, if any.
        if let f = appState.franchise, let l = appState.location {
            await refreshBackingData(appState: appState, franchise: f, location: l)
        }

        // Attempt initial drain (in case we are online at launch).
        await offlineQueue.drain()
    }

    @MainActor
    static func refreshBackingData(appState: AppState, franchise: Franchise, location: LocationRef) async {
        do {
            async let servicesTask = FastAPIService().fetchServices(franchise: franchise.id, location: location.id)
            async let franchiseTask = FastAPIService().fetchFranchiseInfo(franchiseId: franchise.id)
            async let consentsTask = ConsentPDFCache.shared.refreshAll()

            let services = try await servicesTask
            let fInfo = (try? await franchiseTask) ?? FranchiseInfo(customCategoryName: nil)
            _ = await consentsTask

            appState.services = services
            appState.franchiseInfo = fInfo
            appState.catalogFailure = nil
            ServicesCache.save(services)
            FranchiseCache.save(fInfo)
        } catch {
            // Fall back to cached copies, and record WHY the refresh failed so the
            // empty-catalog screen can distinguish "offline" from "server said no".
            appState.catalogFailure = classify(error)
            appState.services = ServicesCache.load()
            appState.franchiseInfo = FranchiseCache.load() ?? FranchiseInfo(customCategoryName: nil)
        }
    }

    private static func classify(_ error: Error) -> AppState.CatalogFailure {
        switch error {
        case APIClient.APIError.status(let code, _) where code == 401 || code == 403:
            return .unauthorized
        case APIClient.APIError.status:
            return .serverError
        default:
            return .offline
        }
    }
}
