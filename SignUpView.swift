import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var toastManager: ToastManager // NEW: Inject Toast Manager
    
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    @State private var showTerms = false
    @State private var agreedToTerms = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.blue.opacity(0.1).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Create Account")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Join the WaterRefill community")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)
                        
                        // Sign Up Form
                        VStack(spacing: 15) {
                            // Email
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Email")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextField("", text: $email)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            }
                            
                            // Username
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Username")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextField("", text: $username)
                                    .autocapitalization(.none)
                                    .textContentType(.username)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            }
                            
                            // Password
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Password")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                SecureField("", text: $password)
                                    .textContentType(.newPassword)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            }
                            
                            // Confirm Password
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Confirm Password")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                SecureField("", text: $confirmPassword)
                                    .textContentType(.newPassword)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                
                                if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                                    Text("Passwords don't match")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding(.top, 2)
                                }
                            }
                            
                            // Terms Agreement
                            HStack {
                                Button(action: {
                                    agreedToTerms.toggle()
                                }) {
                                    Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                        .foregroundColor(agreedToTerms ? .blue : .gray)
                                }
                                
                                Text("I agree to the ")
                                    .font(.caption)
                                
                                Button("Terms & Conditions") {
                                    showTerms = true
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            .padding(.top, 5)
                        }
                        .padding(.horizontal)
                        
                        // Sign Up Button
                        Button(action: signUp) {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Create Account")
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
                        .disabled(!formIsValid() || authManager.isLoading)
                        .opacity(formIsValid() ? 1 : 0.6)
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
            .sheet(isPresented: $showTerms) {
                TermsView(isPresented: $showTerms)
            }
        }
    }
    
    private func formIsValid() -> Bool {
        return !email.isEmpty &&
               !username.isEmpty &&
               !password.isEmpty &&
               password == confirmPassword &&
               password.count >= 6 &&
               agreedToTerms
    }
    
    private func signUp() {
        authManager.signUp(email: email, password: password, username: username) { success, message in
            if success {
                // UPDATED: Use ToastManager for success and dismiss
                toastManager.show(message: "Account created! Please check your email to verify.", isError: false)
                dismiss() // Dismiss on success
            } else if let message = message {
                // UPDATED: Use ToastManager for error
                toastManager.show(message: message, isError: true)
            }
        }
    }
}

// Simple Terms and Conditions View
struct TermsView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Terms & Conditions")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom, 20)
                    
                    Group {
                        Text("1. Acceptance of Terms")
                            .font(.headline)
                        Text("By accessing or using the WaterRefill app, you agree to be bound by these Terms and Conditions.")
                            .padding(.bottom, 10)
                        
                        Text("2. User Content")
                            .font(.headline)
                        Text("Users are responsible for the content they publish on the app. Inappropriate or misleading information about refill locations is prohibited.")
                            .padding(.bottom, 10)
                        
                        Text("3. Privacy")
                            .font(.headline)
                        Text("We collect and process personal data as described in our Privacy Policy. By using the app, you consent to such processing.")
                            .padding(.bottom, 10)
                        
                        Text("4. Account Responsibilities")
                            .font(.headline)
                        Text("You are responsible for maintaining the confidentiality of your account information and for all activities that occur under your account.")
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationBarItems(trailing: Button("Close") {
                isPresented = false
            })
        }
    }
}

#Preview {
    let authManager = AuthManager.shared
    return SignUpView()
        .environmentObject(authManager)
        .environmentObject(ToastManager.shared) // Inject Toast Manager
}
