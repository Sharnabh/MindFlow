import Foundation
import Network

/// Service to monitor network connectivity status
class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    /// Published property for current connection status
    private(set) var isConnected: Bool = false {
        didSet {
            if oldValue != isConnected {
                notifyNetworkStatusChange()
            }
        }
    }
    
    /// Initialize and start monitoring
    init() {
        startMonitoring()
    }
    
    /// Start network monitoring
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
        }
        monitor.start(queue: queue)
    }
    
    /// Stop network monitoring
    func stopMonitoring() {
        monitor.cancel()
    }
    
    /// Notify other components about network status changes
    private func notifyNetworkStatusChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("NetworkStatusChanged"),
                object: nil,
                userInfo: ["isOnline": self.isConnected]
            )
        }
    }
    
    deinit {
        stopMonitoring()
    }
} 