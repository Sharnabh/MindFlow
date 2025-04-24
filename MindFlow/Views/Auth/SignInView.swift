import SwiftUI
import FirebaseAuth

struct SignInView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @EnvironmentObject private var authState: AuthState
    
    @State private var email = ""
    @State private var password = ""
    @State private var isShowingSignUp = false
    @State private var isShowingForgotPassword = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Logo and title
            Image(systemName: "brain.head.profile")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
            
            Text("Welcome to MindFlow")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Sign in to collaborate on mind maps")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Form
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.headline)
                
                TextField("Enter your email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Password")
                    .font(.headline)
                    .padding(.top, 8)
                
                SecureField("Enter your password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                // Error message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top, 4)
                }
                
                // Forgot password
                HStack {
                    Spacer()
                    Button("Forgot Password?") {
                        isShowingForgotPassword = true
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .font(.caption)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            
            // Sign in button
            Button {
                signIn()
            } label: {
                if authService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Sign In")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(email.isEmpty || password.isEmpty || authService.isLoading)
            .padding(.horizontal, 20)
            
            // Divider
            HStack {
                VStack { Divider() }
                Text("OR")
                    .font(.caption)
                    .foregroundColor(.secondary)
                VStack { Divider() }
            }
            .padding(.horizontal, 20)
            
            // Google sign in
            Button {
                signInWithGoogle()
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill") // Fallback to system image if custom image is missing
                        .foregroundColor(.blue)
                    
                    Text("Continue with Google")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal, 20)
            .disabled(authService.isLoading)
            
            // Skip authentication link
            Button("Continue without account") {
                // Close auth screen and continue to app
                authState.skipAuthentication()
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .font(.caption)
            .padding(.top, 16)
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .frame(width: 400)
        .sheet(isPresented: $isShowingSignUp) {
            SignUpView()
                .environmentObject(authService)
                .environmentObject(authState)
        }
        .sheet(isPresented: $isShowingForgotPassword) {
            ForgotPasswordView()
                .environmentObject(authService)
                .environmentObject(authState)
        }
        .onChange(of: authService.error) { _, error in
            if let error = error {
                errorMessage = error.localizedDescription
            }
        }
        .onAppear {
            // Check if there's already an error when the view appears
            if let error = authService.error {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func signIn() {
        errorMessage = ""
        
        Task {
            do {
                try await authService.signIn(email: email, password: password)
                // Success - we'll be redirected by app state
            } catch let error as AuthError {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    print(errorMessage)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "An unknown error occurred. Please try again."
                }
            }
        }
    }
    
    private func signInWithGoogle() {
        errorMessage = ""
        
        Task {
            do {
                try await authService.signInWithGoogle()
                // Success - we'll be redirected by app state
            } catch let error as AuthError {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to sign in with Google. Please try again."
                }
            }
        }
    }
}
