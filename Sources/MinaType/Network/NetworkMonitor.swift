import Foundation
import Network

public class NetworkMonitor {
    public static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "MinaFlowNetworkMonitor")

    public private(set) var isConnected: Bool = true
    private var hasReceivedFirstStatus: Bool = false

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.hasReceivedFirstStatus = true
            self.isConnected = (path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    public func checkConnection() -> Bool {
        // If NWPathMonitor has not dispatched its initial path update yet (typically 200-400ms after launch),
        // assume connected to avoid blocking user's very first keypress.
        if !hasReceivedFirstStatus {
            return true
        }
        return isConnected
    }
}
