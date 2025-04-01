import SwiftUI
import AppKit

struct TopicState {
    let topics: [Topic]
    let selectedTopic: Topic?
    let panOffset: CGSize
    let zoomLevel: CGFloat
}

class TopicUndoRedoViewModel: ObservableObject {
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    @Published var undoError: String?
    
    private var undoStack: [TopicState] = []
    private var redoStack: [TopicState] = []
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUndoRequest),
            name: NSNotification.Name("UndoRequest"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRedoRequest),
            name: NSNotification.Name("RedoRequest"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStateChange),
            name: NSNotification.Name("StateChange"),
            object: nil
        )
    }
    
    @objc private func handleUndoRequest() {
        undo()
    }
    
    @objc private func handleRedoRequest() {
        redo()
    }
    
    @objc private func handleStateChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let state = userInfo["state"] as? TopicState else { return }
        
        addState(state)
    }
    
    func addState(_ state: TopicState) {
        undoStack.append(state)
        redoStack.removeAll()
        updateButtons()
    }
    
    func undo() {
        guard let currentState = undoStack.popLast() else { return }
        redoStack.append(currentState)
        updateButtons()
        
        NotificationCenter.default.post(
            name: NSNotification.Name("StateRestored"),
            object: nil,
            userInfo: ["state": currentState]
        )
    }
    
    func redo() {
        guard let state = redoStack.popLast() else { return }
        undoStack.append(state)
        updateButtons()
        
        NotificationCenter.default.post(
            name: NSNotification.Name("StateRestored"),
            object: nil,
            userInfo: ["state": state]
        )
    }
    
    private func updateButtons() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 