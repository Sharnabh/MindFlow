import Foundation
import SwiftUI

// Protocol defining history operations
protocol HistoryServiceProtocol {
    // State management
    func saveState(_ topics: [Topic])
    func undo() -> [Topic]?
    func redo() -> [Topic]?
    
    // State queries
    var canUndo: Bool { get }
    var canRedo: Bool { get }
    
    // Reset history
    func clearHistory()
}

// Main implementation of the HistoryService
class HistoryService: HistoryServiceProtocol, ObservableObject {
    // History stack
    private var history: [[Topic]] = [[]]
    private var currentHistoryIndex: Int = 0
    private let maxHistorySize: Int = 50
    
    // MARK: - State Management
    
    func saveState(_ topics: [Topic]) {
        // If we're not at the end of the history, truncate it
        if currentHistoryIndex < history.count - 1 {
            history = Array(history.prefix(currentHistoryIndex + 1))
        }
        
        // Create a deep copy of the topics to store in history
        let topicsCopy = topics.map { $0.deepCopy() }
        
        // Add to history
        history.append(topicsCopy)
        currentHistoryIndex = history.count - 1
        
        // Limit history size
        if history.count > maxHistorySize {
            history.removeFirst()
            currentHistoryIndex = history.count - 1
        }
        
        // Publish changes
        objectWillChange.send()
    }
    
    func undo() -> [Topic]? {
        // Check if we can undo
        if !canUndo {
            return nil
        }
        
        // Move back in history
        currentHistoryIndex -= 1
        
        // Make a deep copy of the topics at this history point
        let topicsCopy = history[currentHistoryIndex].map { $0.deepCopy() }
        
        // Publish changes
        objectWillChange.send()
        
        return topicsCopy
    }
    
    func redo() -> [Topic]? {
        // Check if we can redo
        if !canRedo {
            return nil
        }
        
        // Move forward in history
        currentHistoryIndex += 1
        
        // Make a deep copy of the topics at this history point
        let topicsCopy = history[currentHistoryIndex].map { $0.deepCopy() }
        
        // Publish changes
        objectWillChange.send()
        
        return topicsCopy
    }
    
    // MARK: - State Queries
    
    var canUndo: Bool {
        return currentHistoryIndex > 0
    }
    
    var canRedo: Bool {
        return currentHistoryIndex < history.count - 1
    }
    
    // MARK: - Reset History
    
    func clearHistory() {
        history = [[]]
        currentHistoryIndex = 0
        objectWillChange.send()
    }
} 