import SwiftUI
import FirebaseCore

@main
struct WaterRefill2_0App: App {
    // Initialize Firebase when the app starts
    init() {
        FirebaseApp.configure()
    }
    
    // Use the AppStorage property wrapper to read dark mode setting
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some Scene {
        WindowGroup {
            // Use the AuthWrapperView as the root view
            AuthWrapperView()
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}
