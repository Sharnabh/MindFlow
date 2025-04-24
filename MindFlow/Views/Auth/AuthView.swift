import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @EnvironmentObject private var authState: AuthState
    
    var body: some View {
        Group {
            switch authState.currentViewState {
            case .loading:
                ProgressView("Loading...")
                    .onAppear {
                        // Check if already authenticated
                        if authService.isAuthenticated {
                            authState.navigateTo(.authenticated)
                        } else {
                            authState.navigateTo(.signIn)
                        }
                    }
                
            case .signIn:
                SignInView()
                    .environmentObject(authService)
                    .transition(.opacity)
                
            case .signUp:
                SignUpView()
                    .environmentObject(authService)
                    .transition(.opacity)
                
            case .forgotPassword:
                ForgotPasswordView()
                    .environmentObject(authService)
                    .transition(.opacity)
                
            case .phoneAuth:
                PhoneAuthView()
                    .environmentObject(authService)
                    .transition(.opacity)
                
            case .authenticated:
                // Just an empty view as we'll dismiss this flow when authenticated
                Color.clear
                    .onAppear {
                        authState.dismissAuthFlow()
                    }
            }
        }
        .animation(.easeInOut, value: authState.currentViewState)
        .environmentObject(authState)
    }
}

/// This is a modifier to add the auth flow to any view
struct AuthFlowModifier: ViewModifier {
    @StateObject private var authState: AuthState
    @EnvironmentObject private var authService: AuthenticationService
    
    init(authService: AuthenticationService) {
        self._authState = StateObject(wrappedValue: AuthState(authService: authService))
    }
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $authState.showAuthFlow) {
                AuthView()
                    .environmentObject(authService)
                    .environmentObject(authState)
                    .frame(width: 500, height: 600)
            }
            .environment(\.authState, authState)
    }
}

extension View {
    func withAuthFlow(authService: AuthenticationService) -> some View {
        self.modifier(AuthFlowModifier(authService: authService))
    }
}