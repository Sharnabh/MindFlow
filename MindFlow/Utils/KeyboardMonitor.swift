import SwiftUI
import AppKit

class KeyboardMonitor {
    static let shared = KeyboardMonitor()
    private var monitor: Any?
    var keyHandler: ((NSEvent) -> Void)?
    
    private init() {}
    
    func startMonitoring() {
        guard monitor == nil else { return }
        
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            print("KeyboardMonitor received key: \(event.keyCode)")
            self?.keyHandler?(event)
            return event
        }
    }
    
    func stopMonitoring() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
} 