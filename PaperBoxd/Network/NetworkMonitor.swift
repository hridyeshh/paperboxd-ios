import Foundation
import Network
import Combine

/// App-wide network reachability. Publishes `isOnline` so views can catch the
/// offline state *before* kicking off work that needs the network (e.g. opening
/// the scan camera only to have the analyze call fail).
///
/// Starts monitoring on first access and runs for the app's lifetime.
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    /// `true` until the first path update proves otherwise — assume online so we
    /// never block a launch on a slow first callback; the real value lands within
    /// a few milliseconds.
    @Published private(set) var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            DispatchQueue.main.async { self?.isOnline = online }
        }
        monitor.start(queue: queue)
    }
}
