import SwiftUI
import AppKit

class TopicHistoryViewModel: ObservableObject {
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    @Published var historySize: Int = 0
    @Published var currentIndex: Int = -1
    
    private var history: [TopicState] = []
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStateChange),
            name: NSNotification.Name("StateChange"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUndo),
            name: NSNotification.Name("UndoAction"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRedo),
            name: NSNotification.Name("RedoAction"),
            object: nil
        )
    }
    
    @objc private func handleStateChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let state = userInfo["state"] as? TopicState else { return }
        
        addState(state)
    }
    
    @objc private func handleUndo() {
        undo()
    }
    
    @objc private func handleRedo() {
        redo()
    }
    
    func addState(_ state: TopicState) {
        // Remove any states after the current index
        if currentIndex < history.count - 1 {
            history.removeSubrange((currentIndex + 1)...)
        }
        
        // Add the new state
        history.append(state)
        currentIndex = history.count - 1
        
        // Limit history size
        if history.count > 100 {
            history.removeFirst()
            currentIndex -= 1
        }
        
        updateState()
    }
    
    func undo() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        updateState()
        
        NotificationCenter.default.post(
            name: NSNotification.Name("StateRestored"),
            object: nil,
            userInfo: ["state": history[currentIndex]]
        )
    }
    
    func redo() {
        guard currentIndex < history.count - 1 else { return }
        currentIndex += 1
        updateState()
        
        NotificationCenter.default.post(
            name: NSNotification.Name("StateRestored"),
            object: nil,
            userInfo: ["state": history[currentIndex]]
        )
    }
    
    private func updateState() {
        canUndo = currentIndex > 0
        canRedo = currentIndex < history.count - 1
        historySize = history.count
    }
    
    func clearHistory() {
        history.removeAll()
        currentIndex = -1
        updateState()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 