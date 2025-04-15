import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var resetSent = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.blue.opacity(0.1).ignoresSafeArea()
                
                VStack(spacing: 25) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 70))
                            .foregroundColor(.blue)
                        
                        Text("Forgot Password")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Enter your email address to reset your password")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Email field
                    VStack(alignment: .leading) {
                        TextField("Email Address", text: $email)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                    
                    // Reset Button
                    Button(action: resetPassword) {
                        if authManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Reset Password")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                        }
                    }
                    .disabled(email.isEmpty || authManager.isLoading || resetSent)
                    .opacity(email.isEmpty || resetSent ? 0.6 : 1)
                    .padding(.horizontal, 25)
                    
                    if resetSent {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.green)
                            
                            Text("Reset email sent!")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            Text("Please check your inbox and follow the instructions to reset your password.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 20)
                    }
                    
                    Spacer()
                    
                    // Back to login
                    Button(action: {
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Back to Login")
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onChange(of: authManager.errorMessage) { oldValue, newValue in
                if let errorMessage = newValue {
                    alertTitle = "Error"
                    alertMessage = errorMessage
                    showingAlert = true
                }
            }
        }
    }
    
    private func resetPassword() {
        guard !email.isEmpty else { return }
        
        authManager.resetPassword(email: email) { success, message in
            if success {
                resetSent = true
            } else if let message = message {
                alertTitle = "Password Reset Error"
                alertMessage = message
                showingAlert = true
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(AuthManager.shared)
}
