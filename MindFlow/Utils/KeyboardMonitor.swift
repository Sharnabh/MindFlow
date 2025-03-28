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
            
            var shouldPassEvent = true
            
            // Post notification for Return key (code 36)
            if event.keyCode == 36 {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ReturnKeyPressed"),
                    object: nil,
                    userInfo: ["event": event]
                )
                // Always suppress sound for Return key (with or without shift)
                shouldPassEvent = false
            }
            
            // Detect Cmd+Z for Undo (key code 6 is 'z')
            if event.keyCode == 6 && event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.shift) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("UndoRequested"),
                    object: nil,
                    userInfo: ["event": event]
                )
                // Don't play system sound for Cmd+Z
                shouldPassEvent = false
            }
            
            // Detect Cmd+Shift+Z for Redo
            if event.keyCode == 6 && event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("RedoRequested"),
                    object: nil,
                    userInfo: ["event": event]
                )
                // Don't play system sound for Cmd+Shift+Z
                shouldPassEvent = false
            }
            
            self?.keyHandler?(event)
            
            // Return nil for handled events to prevent system sound
            return shouldPassEvent ? event : nil
        }
    }
    
    func stopMonitoring() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
} 