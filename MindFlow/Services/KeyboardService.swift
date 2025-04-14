import Foundation
import AppKit
import SwiftUI

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
    
    // MARK: - Event Handling
    
    func handleKeyPress(_ event: NSEvent, at position: CGPoint, canvasViewModel: CanvasViewModel) {
        // Don't handle keyboard events if text input is active or any topic is being edited
        guard !isTextInputActive && !canvasViewModel.shouldBlockKeyboardShortcuts else {
            // When text input is active, let the system handle the keyboard events naturally
            // without trying to process them for canvas shortcuts
            return
        }
        
        // First check if this is a registered shortcut
        let shortcutKey = ShortcutKey(keyCode: event.keyCode, modifierFlags: event.modifierFlags)
        if let action = shortcuts[shortcutKey] {
            action()
            return
        }
        
        // Handle default key events
        switch event.keyCode {
        case 51: // Delete key
            if let selectedId = canvasViewModel.selectedTopicId {
                canvasViewModel.deleteTopic(withId: selectedId)
            }
        case 36: // Return key
            canvasViewModel.addMainTopic(at: position)
        case 49: // Space key
            if let selectedId = canvasViewModel.selectedTopicId {
                if event.modifierFlags.contains(.control) {
                    // Control+Space to toggle collapse
                    canvasViewModel.collapseExpandTopic(withId: selectedId)
                } else {
                    // Regular Space to edit topic
                    canvasViewModel.beginEditingTopic(withId: selectedId)
                }
            }
        case 48: // Tab key
            if let selectedId = canvasViewModel.selectedTopicId {
                if event.modifierFlags.contains(.shift) {
                    // Shift+Tab: Move topic up one level if possible
                    // This requires knowing the parent, which would be handled by the view model
                } else {
                    // Tab: Create subtopic
                    canvasViewModel.addSubtopic(to: selectedId)
                }
            }
        default:
            break
        }
    }
    
    func isHandlingKeyboardInput() -> Bool {
        return isTextInputActive
    }
    
    func startTextInput() {
        isTextInputActive = true
    }
    
    func endTextInput() {
        isTextInputActive = false
    }
    
    // MARK: - Shortcut Management
    
    func registerShortcut(key: NSEvent.SpecialKey, modifiers: NSEvent.ModifierFlags, action: @escaping () -> Void) {
        let shortcutKey = ShortcutKey(keyCode: UInt16(key.rawValue), modifierFlags: modifiers)
        shortcuts[shortcutKey] = action
    }
    
    func unregisterShortcut(key: NSEvent.SpecialKey, modifiers: NSEvent.ModifierFlags) {
        let shortcutKey = ShortcutKey(keyCode: UInt16(key.rawValue), modifierFlags: modifiers)
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