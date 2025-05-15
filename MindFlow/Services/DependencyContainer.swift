import Foundation
import SwiftUI

// Singleton container for app-wide dependencies
class DependencyContainer {
    // Singleton instance
    static let shared = DependencyContainer()
    
    // Services
    let topicService: TopicServiceProtocol
    let layoutService: LayoutServiceProtocol
    let historyService: HistoryServiceProtocol
    let fileService: FileServiceProtocol
    let themeService: ThemeServiceProtocol
    let keyboardService: KeyboardServiceProtocol
    
    // Private initializer for singleton
    private init() {
        // Initialize services
        topicService = TopicService()
        layoutService = LayoutService()
        historyService = HistoryService()
        fileService = FileService()
        themeService = ThemeService()
        keyboardService = KeyboardService()
        
        // Set up any required connections between services
    }
    
    // Factory method for creating view models with dependencies
    func makeCanvasViewModel() -> CanvasViewModel {
        return CanvasViewModel(
            topicService: topicService as! TopicService,
            layoutService: layoutService,
            historyService: historyService,
            fileService: fileService,
            keyboardService: keyboardService
        )
    }
} 
