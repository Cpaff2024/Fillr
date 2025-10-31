import SwiftUI
import FirebaseCore

@main // <-- CRITICAL: This must be uncommented and only appear ONCE in this file.
struct WaterRefill2_0App: App {

    // Register App Delegate for Firebase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Initialize Firebase when the app starts
    init() {
        FirebaseApp.configure()
        print("WaterRefill2_0App: Firebase configured.")
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

// Make sure there are NO OTHER lines below this that try to define 'struct WaterRefill2_0App: App' again.
// Any duplicate declarations must be completely removed.
