import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
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
                
                Text("Reset Password")
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
                    Image(systemName: "envelope.fill")
                        .resizable()
                        .frame(width: 60, height: 45)
                        .foregroundColor(.accentColor)
                    
                    Text("Reset Email Sent!")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("We've sent password reset instructions to \(email). Please check your inbox and follow the link to reset your password.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Button("Return to Sign In") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            } else {
                // Reset password form
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.headline)
                    
                    TextField("Enter your email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("We'll send you a link to reset your password")
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
                
                // Send reset email button
                Button {
                    sendResetEmail()
                } label: {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Send Reset Link")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(email.isEmpty || isLoading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .padding(.vertical, 20)
        .frame(width: 400, height: 300)
    }
    
    private func sendResetEmail() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await authService.sendPasswordReset(to: email)
                isLoading = false
                showSuccessMessage = true
            } catch let error as AuthError {
                isLoading = false
                errorMessage = error.localizedDescription
            } catch {
                isLoading = false
                errorMessage = "Failed to send reset email. Please try again."
            }
        }
    }
}