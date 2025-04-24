import SwiftUI
import FirebaseAuth
import Combine

enum AuthViewState {
    case loading
    case signIn
    case signUp
    case forgotPassword
    case phoneAuth
    case authenticated
}

class AuthState: ObservableObject {
    @Published var currentViewState: AuthViewState = .loading
    @Published var showAuthFlow = false
    
    private let authService: AuthenticationService
    
    init(authService: AuthenticationService) {
        self.authService = authService
        
        // Observe authentication state changes
        authService.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                guard let self = self else { return }
                
                if isAuthenticated {
                    self.currentViewState = .authenticated
                    self.showAuthFlow = false
                } else if self.currentViewState == .authenticated || self.currentViewState == .loading {
                    // Only change to signIn if we were previously authenticated or loading
                    self.currentViewState = .signIn
                }
            }
            .store(in: &cancellables)
    }
    
    // Store cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // Present the auth flow
    func presentAuthFlow() {
        if authService.isAuthenticated {
            // Already authenticated
            return
        }
        
        currentViewState = .signIn
        showAuthFlow = true
    }
    
    // Dismiss the auth flow
    func dismissAuthFlow() {
        showAuthFlow = false
    }
    
    // Navigate to a specific auth view
    func navigateTo(_ viewState: AuthViewState) {
        currentViewState = viewState
    }
    
    // Skip authentication (allow continuing without account)
    func skipAuthentication() {
        showAuthFlow = false
    }
}

// Extension to add the auth view state to the environment
extension EnvironmentValues {
    private struct AuthStateKey: EnvironmentKey {
        static let defaultValue: AuthState? = nil
    }
    
    var authState: AuthState? {
        get { self[AuthStateKey.self] }
        set { self[AuthStateKey.self] = newValue }
    }
}