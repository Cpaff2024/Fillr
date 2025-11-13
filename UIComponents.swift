import SwiftUI

// MARK: - StatCard
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 24)).foregroundColor(.blue)
            Text(value).font(.title2).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.8)
            Text(label).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(.horizontal, 4)
    }
}

// MARK: - SettingsOptionRow
struct SettingsOptionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.blue).frame(width: 25, alignment: .center)
            Text(text).foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .contentShape(Rectangle())
    }
}

// MARK: - SettingsViewSheet
struct SettingsViewSheet: View {
    @Binding var isPresented: Bool
    // Use AppStorage directly in the view to manage settings persistence
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("defaultSearchRadius") private var defaultRadius: Double = 1.0
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    
    var body: some View {
         NavigationView {
             Form {
                 Section("Map Settings") {
                     VStack(alignment: .leading) {
                         Text("Default Search Radius: \(Int(defaultRadius)) mile\(defaultRadius == 1 ? "" : "s")")
                         Slider(value: $defaultRadius, in: 1...10, step: 1)
                     }
                 }
                 Section("Notifications") {
                     Toggle("Enable Notifications", isOn: $notificationsEnabled)
                 }
                 Section("Appearance") {
                     Toggle("Dark Mode", isOn: $isDarkMode)
                 }
                 Section("About") {
                     HStack {
                         Text("Version")
                         Spacer()
                         Text("2.0.1").foregroundColor(.secondary)
                     }
                     Button("Contact Support") {}
                     Button("Privacy Policy") {}
                     Button("Terms of Service") {}
                 }
             }
             .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline).toolbar {
                 ToolbarItem(placement: .navigationBarTrailing) {
                     Button("Done") { isPresented = false }
                 }
             }
         }
     }
}

// MARK: - ImagePicker (Used by ProfileView)
// This is kept here for reuse, as it's a UI helper component.
struct ImagePicker: UIViewControllerRepresentable {
     @Binding var image: UIImage?
     @Environment(\.presentationMode) private var presentationMode
     
     func makeUIViewController(context: Context) -> UIImagePickerController {
         let picker = UIImagePickerController()
         picker.delegate = context.coordinator
         picker.allowsEditing = true
         return picker
     }
     
     func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
     
     func makeCoordinator() -> Coordinator {
         Coordinator(self)
     }
     
     class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
         let parent: ImagePicker
         init(_ parent: ImagePicker) { self.parent = parent }
         
         func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
             if let img = info[.editedImage] as? UIImage {
                 parent.image = img
             } else if let img = info[.originalImage] as? UIImage {
                 parent.image = img
             }
             parent.presentationMode.wrappedValue.dismiss()
         }
         
         func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
             parent.presentationMode.wrappedValue.dismiss()
         }
     }
}
