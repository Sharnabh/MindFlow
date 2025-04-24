import Foundation
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import SwiftUI
import Combine

enum AuthError: Error, LocalizedError, Equatable {
    case signInFailed(String)
    case signUpFailed(String)
    case userNotFound
    case networkError
    case verificationFailed
    case otpInvalid
    case googleSignInFailed
    case notSupportedOnPlatform
    
    var errorDescription: String? {
        switch self {
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        case .signUpFailed(let message):
            return "Sign up failed: \(message)"
        case .userNotFound:
            return "User not found"
        case .networkError:
            return "Network error. Please check your connection."
        case .verificationFailed:
            return "Failed to send verification code"
        case .otpInvalid:
            return "The verification code is invalid"
        case .googleSignInFailed:
            return "Google sign in was unsuccessful"
        case .notSupportedOnPlatform:
            return "This feature is not supported on macOS"
        }
    }
    
    // Implement Equatable
    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.signInFailed(let lhsMsg), .signInFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.signUpFailed(let lhsMsg), .signUpFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.userNotFound, .userNotFound),
             (.networkError, .networkError),
             (.verificationFailed, .verificationFailed),
             (.otpInvalid, .otpInvalid),
             (.googleSignInFailed, .googleSignInFailed),
             (.notSupportedOnPlatform, .notSupportedOnPlatform):
            return true
        default:
            return false
        }
    }
}

class AuthenticationService: ObservableObject {
    private var auth: Auth
    private var verificationID: String?
    
    // Published properties for observed state
    @Published var currentUser: UserProfile?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: AuthError?
    
    init() {
        self.auth = Auth.auth()
        
        // Fix keychain access issue
        do {
            try auth.useUserAccessGroup("com.sharnabh.MindFlow")
        } catch {
            // If this fails, it's ok - it will fall back to the default behavior
            print("Failed to set user access group: \(error.localizedDescription)")
        }
        
        // Set up authentication state listener
        auth.addStateDidChangeListener { [weak self] (_, user) in
            guard let self = self else { return }
            
            // Ensure UI updates happen on the main thread
            DispatchQueue.main.async {
                self.isAuthenticated = user != nil
                
                if let user = user {
                    // Convert Firebase user to our user model
                    self.currentUser = UserProfile(from: user)
                    
                    // Save to Firestore database as well (we'll implement this later)
                    self.saveUserProfile()
                } else {
                    self.currentUser = nil
                }
            }
        }
    }
    
    // MARK: - Email Password Authentication
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        // Update UI state on main thread
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            
            // Update UI state on main thread
            await MainActor.run {
                self.currentUser = UserProfile(from: result.user)
                isLoading = false
            }
        } catch {
            // Update UI state on main thread
            await MainActor.run {
                isLoading = false
                let authError = mapFirebaseError(error)
                self.error = authError
            }
            throw mapFirebaseError(error)
        }
    }
    
    /// Create a new account with email and password
    func signUp(email: String, password: String, displayName: String) async throws {
        // Update UI state on main thread
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            
            // Set the user's display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
            
            // Send verification email
            try await result.user.sendEmailVerification()
            
            // Update UI state on main thread
            await MainActor.run {
                // Update our local user
                self.currentUser = UserProfile(from: result.user)
                isLoading = false
            }
        } catch {
            // Update UI state on main thread
            await MainActor.run {
                isLoading = false
                let authError = mapFirebaseError(error)
                self.error = authError
            }
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - Phone Authentication
    
    /// Send a verification code to a phone number
    func sendVerificationCode(to phoneNumber: String) async throws {
        // Update UI state on main thread
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        // For now, returning not supported on macOS
        await MainActor.run {
            isLoading = false
            self.error = .notSupportedOnPlatform
        }
        throw AuthError.notSupportedOnPlatform
        
        // Note: A real implementation would need to use a different approach for macOS
        // such as using a web flow or a different verification method
    }
    
    /// Verify OTP code sent to phone number
    func verifyOTP(_ code: String) async throws {
        // Similarly, this won't work on macOS the same way as iOS
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        await MainActor.run {
            isLoading = false
            self.error = .notSupportedOnPlatform
        }
        throw AuthError.notSupportedOnPlatform
    }
    
    // MARK: - Google Sign In
    
    /// Sign in with Google
    func signInWithGoogle() async throws {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            await MainActor.run {
                isLoading = false
                self.error = .googleSignInFailed
            }
            throw AuthError.googleSignInFailed
        }
        
        // Create Google Sign In configuration object
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        do {
            // macOS implementation needs NSWindow
            guard let window = NSApplication.shared.windows.first else {
                throw AuthError.googleSignInFailed
            }
            
            // Get the root view controller - using the window directly for macOS
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: window)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.googleSignInFailed
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                          accessToken: result.user.accessToken.tokenString)
            
            // Use a try-catch specifically for the Firebase sign-in to better handle keychain errors
            do {
                let authResult = try await auth.signIn(with: credential)
                
                await MainActor.run {
                    self.currentUser = UserProfile(from: authResult.user)
                    isLoading = false
                }
            } catch {
                // Check if this is a keychain error
                let nsError = error as NSError
                if nsError.domain == NSOSStatusErrorDomain || 
                   error.localizedDescription.contains("keychain") {
                    print("Keychain error during Google sign-in: \(error.localizedDescription)")
                    
                    // Still throw but with more specific error
                    await MainActor.run {
                        isLoading = false
                        self.error = .signInFailed("Keychain access error. Please check app permissions.")
                    }
                    throw AuthError.signInFailed("Keychain access error. Please check app permissions.")
                } else {
                    // For other errors
                    await MainActor.run {
                        isLoading = false
                        self.error = .googleSignInFailed
                    }
                    throw AuthError.googleSignInFailed
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                if let authError = error as? AuthError {
                    self.error = authError
                } else {
                    self.error = .googleSignInFailed
                }
            }
            if let authError = error as? AuthError {
                throw authError
            } else {
                throw AuthError.googleSignInFailed
            }
        }
    }
    
    // MARK: - Sign Out
    
    /// Sign out the current user
    func signOut() throws {
        do {
            try auth.signOut()
            // Always update UI on main thread
            DispatchQueue.main.async {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        } catch {
            throw AuthError.signInFailed("Failed to sign out")
        }
    }
    
    // MARK: - Password Reset
    
    /// Send password reset email
    func sendPasswordReset(to email: String) async throws {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            try await auth.sendPasswordReset(withEmail: email)
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                let authError = mapFirebaseError(error)
                self.error = authError
            }
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - Profile Management
    
    /// Update the user's profile
    func updateProfile(displayName: String?, photoURL: URL?) async throws {
        guard let user = auth.currentUser else {
            await MainActor.run {
                self.error = .userNotFound
            }
            throw AuthError.userNotFound
        }
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let changeRequest = user.createProfileChangeRequest()
            
            if let displayName = displayName {
                changeRequest.displayName = displayName
            }
            
            if let photoURL = photoURL {
                changeRequest.photoURL = photoURL
            }
            
            try await changeRequest.commitChanges()
            
            await MainActor.run {
                // Update our local user
                if var currentUser = self.currentUser {
                    currentUser.update(from: user)
                    self.currentUser = currentUser
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                self.error = .signInFailed("Failed to update profile")
            }
            throw AuthError.signInFailed("Failed to update profile")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Save the user profile to Firestore
    private func saveUserProfile() {
        // We'll implement this later when adding Firestore
    }
    
    /// Map Firebase Auth errors to our custom errors
    private func mapFirebaseError(_ error: Error) -> AuthError {
        let nsError = error as NSError
        
        // For Firebase Auth errors, check the error domain and code
        if nsError.domain == AuthErrorDomain {
            switch nsError.code {
            case 17011: // userNotFound
                return .userNotFound
            case 17020: // networkError
                return .networkError
            case 17009, 17008, 17005, 17006: // wrongPassword, invalidEmail, userDisabled, operationNotAllowed
                return .signInFailed(error.localizedDescription)
            case 17007, 17026: // emailAlreadyInUse, weakPassword
                return .signUpFailed(error.localizedDescription)
            default:
                return .signInFailed("Firebase auth error: \(error.localizedDescription)")
            }
        }
        
        // Check for keychain access issues
        if nsError.domain == NSOSStatusErrorDomain || 
           error.localizedDescription.contains("keychain") {
            // Provide a more helpful message for keychain issues
            return .signInFailed("Keychain access error. Please check your app permissions or try signing out and in again.")
        }
        
        return .signInFailed("An unexpected error occurred: \(error.localizedDescription)")
    }
}
