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
            print("KeyboardMonitor received key: \(event.keyCode), modifiers: \(event.modifierFlags.rawValue)")
            
            var shouldPassEvent = true
            
            // Post notification for Return key (code 36)
            if event.keyCode == 36 {
                // Log the modifiers for debugging
                let isCommandPressed = event.modifierFlags.contains(.command)
                let isShiftPressed = event.modifierFlags.contains(.shift)
                print("Return pressed - Command: \(isCommandPressed), Shift: \(isShiftPressed)")
                
                // Post notification with the event for our custom handlers
                NotificationCenter.default.post(
                    name: NSNotification.Name("ReturnKeyPressed"),
                    object: nil,
                    userInfo: ["event": event]
                )
                
                // For Command+Return and Shift+Return, always prevent the default behavior
                // to avoid duplicate newlines in TextEditor - our handler will insert the newline
                if isCommandPressed || isShiftPressed {
                    // Check if the first responder is a TextEditor/NSTextView
                    if let window = NSApp.keyWindow,
                       let firstResponder = window.firstResponder,
                       firstResponder.isKind(of: NSTextView.self) {
                        // For TextEditor with modifiers, always stop the event here
                        // Our notification handler will insert exactly one newline
                        shouldPassEvent = false
                    }
                } else {
                    // For plain Return, check what type of control has focus
                    if let window = NSApp.keyWindow,
                       let firstResponder = window.firstResponder {
                        // For NSTextView (TextEditor), let system handle regular Return
                        if firstResponder.isKind(of: NSTextView.self) {
                            shouldPassEvent = true
                        } else {
                            // For other controls, let our custom handlers decide
                            shouldPassEvent = true
                        }
                    }
                }
            }
            
            // Handle Tab key (keyCode 48) - prevent focus traversal in canvas
            if event.keyCode == 48 {
                // Check if we're in text editing mode
                if let window = NSApp.keyWindow,
                   let firstResponder = window.firstResponder {
                    
                    // If we're not in a text field or text view
                    if !firstResponder.isKind(of: NSTextView.self) && 
                       !firstResponder.isKind(of: NSTextField.self) {
                        // Process the key event in the canvas first
                        self?.keyHandler?(event)
                        
                        // Don't let the tab event propagate to prevent focus traversal
                        return nil
                    }
                }
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
            
            // Return nil for handled events to prevent system sound and default behavior
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