import SwiftUI

struct PhoneAuthView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var isVerificationSent = false
    
    // For OTP input
    @State private var isFocused = false
    @FocusState private var focusedField: Bool
    
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
                
                Text(isVerificationSent ? "Verify Code" : "Phone Sign In")
                    .font(.headline)
                
                Spacer()
                
                // Balance the layout
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundColor(.clear) // Invisible
            }
            .padding(.horizontal)
            
            if !isVerificationSent {
                // Phone number input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone Number")
                        .font(.headline)
                    
                    TextField("Enter your phone number (+1 555-555-5555)", text: $phoneNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("We'll send a verification code to this number")
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
                
                // Send verification code button
                Button {
                    sendVerificationCode()
                } label: {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Send Verification Code")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(phoneNumber.isEmpty || isLoading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
            } else {
                // Verification code input
                VStack(alignment: .center, spacing: 20) {
                    Image(systemName: "message.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundColor(.accentColor)
                    
                    Text("Enter Verification Code")
                        .font(.headline)
                    
                    Text("We've sent a verification code to \(phoneNumber)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // OTP input field
                    TextField("", text: $verificationCode)
                        .focused($focusedField)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 24, weight: .bold))
                        .frame(height: 50)
                        .padding(.horizontal)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(focusedField ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                        )
                        .padding(.horizontal, 40)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                focusedField = true
                            }
                        }
                    
                    // Error message
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.top, 8)
                    }
                    
                    // Verify code button
                    Button {
                        verifyCode()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Verify Code")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(verificationCode.isEmpty || isLoading)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Resend code button
                    Button("Didn't receive a code? Resend") {
                        resendCode()
                    }
                    .font(.footnote)
                    .foregroundColor(.accentColor)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
        }
        .padding(.vertical, 20)
        .frame(width: 400, height: 400)
    }
    
    private func sendVerificationCode() {
        // Basic validation
        let formattedNumber = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !formattedNumber.hasPrefix("+") {
            errorMessage = "Please include the country code (e.g., +1 for US)"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await authService.sendVerificationCode(to: formattedNumber)
                isLoading = false
                isVerificationSent = true
            } catch {
                isLoading = false
                errorMessage = "Failed to send verification code. Please check your phone number and try again."
            }
        }
    }
    
    private func verifyCode() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await authService.verifyOTP(verificationCode)
                isLoading = false
                dismiss() // Successfully authenticated, return to main flow
            } catch {
                isLoading = false
                errorMessage = "Invalid verification code. Please try again."
            }
        }
    }
    
    private func resendCode() {
        sendVerificationCode()
    }
}