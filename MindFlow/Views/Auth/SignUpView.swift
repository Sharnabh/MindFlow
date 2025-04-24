import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showSuccessMessage = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("Create Account")
                    .font(.headline)
                
                Spacer()
                
                // Balance the layout
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundColor(.clear) // Invisible
            }
            .padding(.horizontal)
            
            if showSuccessMessage {
                // Success message
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.green)
                    
                    Text("Account Created Successfully!")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("We've sent a verification email to \(email). Please verify your email to complete the registration.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Button("Continue to Sign In") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            } else {
                // Registration form
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full Name")
                            .font(.headline)
                        
                        TextField("Enter your name", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("Email")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("Password")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        SecureField("Create a password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("Confirm Password")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        SecureField("Confirm your password", text: $confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        // Password requirements
                        Text("Password must be at least 8 characters with a number and special character")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        
                        // Error message
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Sign up button
                    Button {
                        signUp()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Create Account")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(name.isEmpty || email.isEmpty || password.isEmpty || 
                             confirmPassword.isEmpty || password != confirmPassword || 
                             password.count < 8 || isLoading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Terms and conditions
                    Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.top, 16)
                }
            }
        }
        .padding(.vertical, 20)
        .frame(width: 400, height: 550)
    }
    
    private func signUp() {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        if password.count < 8 {
            errorMessage = "Password must be at least 8 characters"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await authService.signUp(email: email, password: password, displayName: name)
                isLoading = false
                showSuccessMessage = true
            } catch let error as AuthError {
                isLoading = false
                errorMessage = error.localizedDescription
            } catch {
                isLoading = false
                errorMessage = "An unknown error occurred. Please try again."
            }
        }
    }
}