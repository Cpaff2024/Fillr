import SwiftUI

struct AuthWrapperView: View {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // User is authenticated, show the main app
                MapView()
                    .environmentObject(authManager)
            } else {
                // User is not authenticated, show the login screen
                LoginView()
                    .environmentObject(authManager)
            }
        }
    }
}

#Preview {
    AuthWrapperView()
}
