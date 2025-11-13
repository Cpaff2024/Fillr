import SwiftUI

// MARK: - Toast Manager
// An ObservableObject to hold the state of a global toast message
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var showToast: Bool = false
    @Published var message: String = ""
    @Published var isError: Bool = false
    
    private init() {}
    
    /// Displays a new toast message.
    func show(message: String, isError: Bool = false) {
        // Clear any existing toast state immediately
        self.message = ""
        self.isError = false
        self.showToast = false

        // Update with new message and trigger display after a small delay
        // This ensures the transition happens correctly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.message = message
            self.isError = isError
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.showToast = true
            }
            
            // Hide automatically after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.showToast = false
                }
            }
        }
    }
}

// MARK: - Toast Overlay View
// This view should be placed at the root of a ZStack to cover the screen
struct ToastOverlay: View {
    @EnvironmentObject var toastManager: ToastManager

    var body: some View {
         VStack {
             Spacer()
             if toastManager.showToast {
                 Text(toastManager.message)
                     .padding()
                     .background(toastManager.isError ? Color.red.opacity(0.9) : Color.green.opacity(0.9))
                     .foregroundColor(.white).cornerRadius(10).shadow(radius: 3)
                     .transition(.move(edge: .bottom).combined(with: .opacity))
                      .padding(.bottom, 20)
             }
         }
         .padding(.horizontal)
         .animation(.spring(), value: toastManager.showToast)
    }
}
