import Foundation
import SwiftUI
import FirebaseCore
import FirebaseAppCheck

// Singleton container for app-wide dependencies
class DependencyContainer {
    // Singleton instance
    static let shared = DependencyContainer()
    
    // Services
    private let authService: AuthenticationService
    private let canvasViewModel: CanvasViewModel
    private let apiClient: APIClient
    private let collaborationService: CollaborationService
    private let documentSharingService: DocumentSharingService
    private let topicChangeTracker: TopicChangeTracker
    private let networkMonitor: NetworkMonitor
    private let themeService: ThemeService
    
    // Private initializer for singleton
    private init() {
        // Configure Firebase
        // Set App Check to use no-op implementation to avoid token errors
        let providerFactory = UnsafeAppCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        
        FirebaseApp.configure()
        
        // Initialize network monitoring first
        self.networkMonitor = NetworkMonitor()
        
        // Initialize services
        self.authService = AuthenticationService()
        self.apiClient = APIClient()
        
        // Configure for local development server
        #if DEBUG
        self.apiClient.configureForLocalServer()
        #endif
        
        self.collaborationService = CollaborationService()
        self.themeService = ThemeService()
        self.documentSharingService = DocumentSharingService(
            apiClient: apiClient,
            authService: authService
        )
        self.topicChangeTracker = TopicChangeTracker(
            collaborationService: collaborationService,
            authService: authService
        )
        
        // Create view models
        self.canvasViewModel = CanvasViewModel(
            topicService: TopicService(changeTracker: topicChangeTracker),
            layoutService: LayoutService(),
            historyService: HistoryService(),
            fileService: FileService(),
            keyboardService: KeyboardService()
        )
        
        // Set up any required connections between services
    }
    
    // Getter for authentication service
    func makeAuthService() -> AuthenticationService {
        return authService
    }
    
    // Getter for canvas view model
    func makeCanvasViewModel() -> CanvasViewModel {
        return canvasViewModel
    }
    
    // Getter for API client
    func makeAPIClient() -> APIClient {
        return apiClient
    }
    
    // Getter for collaboration service
    func makeCollaborationService() -> CollaborationService {
        return collaborationService
    }
    
    // Getter for document sharing service
    func makeDocumentSharingService() -> DocumentSharingService {
        return documentSharingService
    }
    
    // Getter for topic change tracker
    func makeTopicChangeTracker() -> TopicChangeTracker {
        return topicChangeTracker
    }
    
    // Getter for network monitor
    func makeNetworkMonitor() -> NetworkMonitor {
        return networkMonitor
    }
    
    // Getter for theme service
    func makeThemeService() -> ThemeService {
        return themeService
    }
}

// Custom App Check provider factory that doesn't try to verify anything
// This allows authentication to work without requiring App Check setup
class UnsafeAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        return nil  // Return nil to disable App Check completely
    }
}
