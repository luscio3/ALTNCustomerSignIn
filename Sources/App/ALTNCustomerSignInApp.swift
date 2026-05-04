import SwiftUI

@main
struct ALTNCustomerSignInApp: App {

    @StateObject private var appState = AppState()
    @StateObject private var connectivity = ConnectivityMonitor()
    @StateObject private var offlineQueue = OfflineQueue()
    @StateObject private var localization = Localization.shared

    init() {
        // Kick off background bootstrap: services catalog + consent PDFs.
        // Must be on main actor because our services are @MainActor.
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(connectivity)
                .environmentObject(offlineQueue)
                .environmentObject(localization)
                .preferredColorScheme(.light)
                .task {
                    await Bootstrap.run(
                        appState: appState,
                        connectivity: connectivity,
                        offlineQueue: offlineQueue
                    )
                }
        }
    }
}
