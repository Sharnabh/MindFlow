import SwiftUI
import AppKit

class TopicKeyboardViewModel: ObservableObject {
    @Published var isHandlingShortcut: Bool = false
    @Published var shortcutError: String?
    
    private var shortcuts: [KeyboardShortcut: () -> Void] = [:]
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyDown),
            name: NSNotification.Name("KeyDown"),
            object: nil
        )
    }
    
    @objc private func handleKeyDown(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let event = userInfo["event"] as? NSEvent else { return }
        
        handleKeyEvent(event)
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        isHandlingShortcut = true
        shortcutError = nil
        
        let shortcut = KeyboardShortcut(
            key: event.keyCode,
            modifiers: event.modifierFlags
        )
        
        if let action = shortcuts[shortcut] {
            action()
        }
        
        isHandlingShortcut = false
    }
    
    func registerShortcut(_ shortcut: KeyboardShortcut, action: @escaping () -> Void) {
        shortcuts[shortcut] = action
    }
    
    func unregisterShortcut(_ shortcut: KeyboardShortcut) {
        shortcuts.removeValue(forKey: shortcut)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct KeyboardShortcut: Hashable {
    let key: UInt16
    let modifiers: NSEvent.ModifierFlags
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(modifiers.rawValue)
    }
    
    static func == (lhs: KeyboardShortcut, rhs: KeyboardShortcut) -> Bool {
        lhs.key == rhs.key && lhs.modifiers == rhs.modifiers
    }
} 