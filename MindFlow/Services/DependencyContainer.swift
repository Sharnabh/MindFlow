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
    let icloudService: iCloudService
    
    // Cached shared CanvasViewModel instance to prevent re-creation during scene re-renders
    private var _cachedCanvasViewModel: CanvasViewModel?
    
    // Private initializer for singleton
    private init() {
        // Initialize services
        topicService = TopicService()
        layoutService = LayoutService()
        historyService = HistoryService()
        fileService = FileService()
        themeService = ThemeService()
        keyboardService = KeyboardService()
        icloudService = iCloudService.shared
        
        // Set up any required connections between services
    }
    
    // Factory method for creating or retrieving the shared view model with dependencies
    func makeCanvasViewModel(createNew: Bool = false) -> CanvasViewModel {
        if !createNew, let existing = _cachedCanvasViewModel {
            return existing
        }
        
        let newViewModel = CanvasViewModel(
            topicService: topicService as! TopicService,
            layoutService: layoutService,
            historyService: historyService,
            fileService: fileService,
            keyboardService: keyboardService
        )
        
        if !createNew {
            _cachedCanvasViewModel = newViewModel
        }
        return newViewModel
    }
} 
