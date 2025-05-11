import SwiftUI
import AppKit
import Cocoa

// MARK: - Key Code Constants
enum KeyCode {
    static let returnKey = UInt16(36)
    static let deleteKey = UInt16(51)
    static let tabKey = UInt16(48)
    static let spaceKey = UInt16(49)
    static let zKey = UInt16(6)
}

// MARK: - Notification Name Constants
extension NSNotification.Name {
    static let returnKeyPressed = NSNotification.Name("ReturnKeyPressed")
    static let undoRequested = NSNotification.Name("UndoRequested")
    static let redoRequested = NSNotification.Name("RedoRequested")
    static let returnFocusToCanvas = NSNotification.Name("ReturnFocusToCanvas")
    static let keyDown = NSNotification.Name("KeyDown")
}

// MARK: - KeyboardMonitor Protocol for testability
protocol KeyboardMonitorProtocol {
    var keyHandler: ((NSEvent) -> Void)? { get set }
    func startMonitoring()
    func stopMonitoring()
}

// MARK: - NotificationCenter Protocol for testability
protocol NotificationCenterProtocol {
    func post(name: NSNotification.Name, object: Any?, userInfo: [AnyHashable: Any]?)
}

// Extension to allow standard NotificationCenter to conform to our protocol
extension NotificationCenter: NotificationCenterProtocol {}

class KeyboardMonitor: KeyboardMonitorProtocol {
    // Singleton instance for backward compatibility
    static let shared = KeyboardMonitor()
    
    // Callback handler
    var keyHandler: ((NSEvent) -> Void)?
    
    // Event monitor reference
    private var monitor: Any?
    private var eventMonitor: Any?
    
    // Notification center
    private let notificationCenter: NotificationCenterProtocol
    
    // Initializer with dependency injection for both singleton and testing
    init(notificationCenter: NotificationCenterProtocol = NotificationCenter.default) {
        self.notificationCenter = notificationCenter
    }
    
    func startMonitoring() {
        guard monitor == nil else { return }
        
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            print("KeyboardMonitor received key: \(event.keyCode), modifiers: \(event.modifierFlags.rawValue)")
            
            var shouldPassEvent = true
            
            // Post notification for Return key
            if event.keyCode == KeyCode.returnKey {
                // Log the modifiers for debugging
                let isCommandPressed = event.modifierFlags.contains(.command)
                let isShiftPressed = event.modifierFlags.contains(.shift)
                print("Return pressed - Command: \(isCommandPressed), Shift: \(isShiftPressed)")
                
                // Post notification with the event for our custom handlers
                self?.notificationCenter.post(
                    name: .returnKeyPressed,
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
            
            // Handle Tab key - prevent focus traversal in canvas
            if event.keyCode == KeyCode.tabKey {
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
            
            // Detect Cmd+Z for Undo
            if event.keyCode == KeyCode.zKey && event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.shift) {
                self?.notificationCenter.post(
                    name: .undoRequested,
                    object: nil,
                    userInfo: ["event": event]
                )
                // Don't play system sound for Cmd+Z
                shouldPassEvent = false
            }
            
            // Detect Cmd+Shift+Z for Redo
            if event.keyCode == KeyCode.zKey && event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) {
                self?.notificationCenter.post(
                    name: .redoRequested,
                    object: nil,
                    userInfo: ["event": event]
                )
                // Don't play system sound for Cmd+Shift+Z
                shouldPassEvent = false
            }
            
            self?.keyHandler?(event)
            
            // Post notification so it can be observed elsewhere
            NotificationCenter.default.post(name: .keyDown, object: event)
            
            // Return nil for handled events to prevent system sound and default behavior
            return shouldPassEvent ? event : nil
        }
    }
    
    func stopMonitoring() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}