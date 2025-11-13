import SwiftUI

struct AuthWrapperView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var toastManager = ToastManager.shared // NEW: Inject Toast Manager here

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
        // Provide the ToastManager to the entire view hierarchy
        .environmentObject(toastManager)
        // Overlay the Toast at the root level of the visible UI
        .overlay(
            ToastOverlay()
                .environmentObject(toastManager)
        )
    }
}

#Preview {
    AuthWrapperView()
}
