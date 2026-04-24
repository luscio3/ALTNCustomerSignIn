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

        // Drain the offline queue whenever the network comes back.
        connectivity.onReconnect = {
            Task { await offlineQueue.drain() }
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
            ServicesCache.save(services)
            FranchiseCache.save(fInfo)
        } catch {
            // Offline or transient — fall back to cached copies.
            appState.services = ServicesCache.load()
            appState.franchiseInfo = FranchiseCache.load() ?? FranchiseInfo(customCategoryName: nil)
        }
    }
}
