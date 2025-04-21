import Foundation
import AppKit
import SwiftUI
import os.log

// Protocol for logging to allow mocking in tests
protocol LoggerProtocol {
    func debug(_ message: String)
    func error(_ message: String)
}

// Concrete Logger implementation
class AppLogger: LoggerProtocol {
    private let logger: Logger
    
    init(category: String) {
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mindflow", category: category)
    }
    
    func debug(_ message: String) {
        logger.debug("\(message)")
    }
    
    func error(_ message: String) {
        logger.error("\(message)")
    }
}

// Protocol defining keyboard handling operations
protocol KeyboardServiceProtocol {
    // Event handling
    func handleKeyPress(_ event: NSEvent, at position: CGPoint, canvasViewModel: CanvasViewModel)
    func isHandlingKeyboardInput() -> Bool
    func startTextInput()
    func endTextInput()
    
    // Shortcut management
    func registerShortcut(key: NSEvent.SpecialKey, modifiers: NSEvent.ModifierFlags, action: @escaping () -> Void)
    func unregisterShortcut(key: NSEvent.SpecialKey, modifiers: NSEvent.ModifierFlags)
}

// Main implementation of the KeyboardService
class KeyboardService: KeyboardServiceProtocol, ObservableObject {
    // State tracking
    @Published private var isTextInputActive: Bool = false
    
    // Registered shortcuts
    private var shortcuts: [ShortcutKey: () -> Void] = [:]
    
    // Logger
    private let logger: LoggerProtocol
    
    // MARK: - Initialization
    
    init(logger: LoggerProtocol? = nil) {
        self.logger = logger ?? AppLogger(category: "KeyboardService")
    }
    
    // MARK: - Event Handling
    
    func handleKeyPress(_ event: NSEvent, at position: CGPoint, canvasViewModel: CanvasViewModel) {
        // Don't handle keyboard events if text input is active or any topic is being edited
        guard !isTextInputActive && !canvasViewModel.shouldBlockKeyboardShortcuts else {
            // When text input is active, let the system handle the keyboard events naturally
            // without trying to process them for canvas shortcuts
            logger.debug("Ignoring keyboard event due to active text input or editing state")
            return
        }
        
        // First check if this is a registered shortcut
        let shortcutKey = ShortcutKey(keyCode: event.keyCode, modifierFlags: event.modifierFlags)
        if let action = shortcuts[shortcutKey] {
            logger.debug("Executing registered shortcut action for key code: \(event.keyCode)")
            action()
            return
        }
        
        // Handle default key events
        switch event.keyCode {
        case KeyCode.deleteKey:
            if let selectedId = canvasViewModel.selectedTopicId {
                logger.debug("Delete key pressed - removing topic with ID: \(selectedId)")
                canvasViewModel.deleteTopic(withId: selectedId)
            } else {
                logger.debug("Delete key pressed but no topic selected")
            }
            
        case KeyCode.returnKey:
            logger.debug("Return key pressed - adding main topic at position: \(position)")
            canvasViewModel.addMainTopic(at: position)
            
        case KeyCode.spaceKey:
            if let selectedId = canvasViewModel.selectedTopicId {
                if event.modifierFlags.contains(.control) {
                    // Control+Space to toggle collapse
                    logger.debug("Control+Space pressed - toggling collapsed state for topic: \(selectedId)")
                    canvasViewModel.collapseExpandTopic(withId: selectedId)
                } else {
                    // Regular Space to edit topic
                    logger.debug("Space pressed - beginning editing for topic: \(selectedId)")
                    canvasViewModel.beginEditingTopic(withId: selectedId)
                }
            } else {
                logger.debug("Space key pressed but no topic selected")
            }
            
        case KeyCode.tabKey:
            if let selectedId = canvasViewModel.selectedTopicId {
                if event.modifierFlags.contains(.shift) {
                    // Shift+Tab: Move topic up one level if possible
                    logger.debug("Shift+Tab pressed - handling parent level navigation not implemented")
                    // This requires knowing the parent, which would be handled by the view model
                } else {
                    // Tab: Create subtopic
                    logger.debug("Tab pressed - adding subtopic to: \(selectedId)")
                    canvasViewModel.addSubtopic(to: selectedId)
                }
            } else {
                logger.debug("Tab key pressed but no topic selected")
            }
            
        default:
            logger.debug("Unhandled key code: \(event.keyCode)")
            break
        }
    }
    
    func isHandlingKeyboardInput() -> Bool {
        return isTextInputActive
    }
    
    func startTextInput() {
        logger.debug("Starting text input mode")
        isTextInputActive = true
    }
    
    func endTextInput() {
        logger.debug("Ending text input mode")
        isTextInputActive = false
    }
    
    // MARK: - Shortcut Management
    
    func registerShortcut(key: NSEvent.SpecialKey, modifiers: NSEvent.ModifierFlags, action: @escaping () -> Void) {
        let shortcutKey = ShortcutKey(keyCode: UInt16(key.rawValue), modifierFlags: modifiers)
        logger.debug("Registering shortcut with key: \(key.rawValue), modifiers: \(modifiers.rawValue)")
        shortcuts[shortcutKey] = action
    }
    
    func unregisterShortcut(key: NSEvent.SpecialKey, modifiers: NSEvent.ModifierFlags) {
        let shortcutKey = ShortcutKey(keyCode: UInt16(key.rawValue), modifierFlags: modifiers)
        logger.debug("Unregistering shortcut with key: \(key.rawValue), modifiers: \(modifiers.rawValue)")
        shortcuts.removeValue(forKey: shortcutKey)
    }
    
    // MARK: - Helper Types
    
    // Helper struct to uniquely identify a shortcut
    private struct ShortcutKey: Hashable {
        let keyCode: UInt16
        let modifierFlags: NSEvent.ModifierFlags
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(keyCode)
            hasher.combine(modifierFlags.rawValue)
        }
        
        static func == (lhs: ShortcutKey, rhs: ShortcutKey) -> Bool {
            return lhs.keyCode == rhs.keyCode && lhs.modifierFlags == rhs.modifierFlags
        }
    }
} 