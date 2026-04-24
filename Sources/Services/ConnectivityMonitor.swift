import Foundation
import Network

/// Tracks Internet reachability and fires `onReconnect` when the link comes back.
/// Cheap enough to keep running for the life of the app.
@MainActor
final class ConnectivityMonitor: ObservableObject {

    @Published private(set) var isOnline: Bool = true

    /// Called on the main actor each time the device transitions from offline → online.
    var onReconnect: (() -> Void)?

    private let monitor = NWPathMonitor()
    private let queue   = DispatchQueue(label: "ConnectivityMonitor")
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = online
                if wasOffline && online {
                    self.onReconnect?()
                }
            }
        }
        monitor.start(queue: queue)
    }
}
