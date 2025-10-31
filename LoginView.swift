import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = false
    
    @State private var showingForgotPassword = false
    @State private var showingSignUp = false
    
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.blue.opacity(0.1).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Logo and Title
                    VStack(spacing: 10) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.blue)
                        
                        // --- NAME CHANGE HERE ---
                        Text("Fillr")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Welcome Back!")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 50)
                    .padding(.bottom, 40)
                    
                    // Login Form
                    VStack(spacing: 16) {
                        // Email Field
                        TextField("Email", text: $email)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
                        
                        // Password Field
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
                        
                        // Remember Me & Forgot Password
                        HStack {
                            Toggle("Remember me", isOn: $rememberMe)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Button("Forgot Password?") {
                                showingForgotPassword = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        .padding(.vertical, 5)
                    }
                    .padding(.horizontal)
                    
                    // Sign In Button
                    Button(action: signIn) {
                        if authManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Sign In")
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
                    .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Sign Up Option
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(.secondary)
                        
                        Button("Sign Up") {
                            showingSignUp = true
                        }
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarHidden(true)
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .fullScreenCover(isPresented: $showingForgotPassword) {
                ForgotPasswordView()
                    .environmentObject(authManager)
            }
            .fullScreenCover(isPresented: $showingSignUp) {
                SignUpView()
                    .environmentObject(authManager)
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
    
    private func signIn() {
        authManager.signIn(email: email, password: password) { success, message in
            if !success, let message = message {
                alertTitle = "Sign In Error"
                alertMessage = message
                showingAlert = true
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager.shared)
}
