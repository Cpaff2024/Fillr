import SwiftUI
import MapKit // Keep MapKit for coordinate display if needed elsewhere
import CoreLocation // Keep if coordinate needed
import UIKit
import PhotosUI // Keep for ImagePicker

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    // Only include stationsViewModel if truly needed in this specific view
    // @StateObject private var stationsViewModel = RefillStationsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showSettingsView = false
    @State private var showingImagePicker = false
    @State private var inputImage: UIImage?
    @State private var profileImage: UIImage? = nil // Holds the displayed image
    @State private var isLoadingImage = false

    // Alert state
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    VStack(spacing: 12) {
                        // Profile Image section
                        ZStack(alignment: .bottomTrailing) { // Alignment for button overlay
                            Group { // Group contents for conditional logic
                                if isLoadingImage {
                                    Circle().fill(Color.blue.opacity(0.1)).frame(width: 100, height: 100)
                                    ProgressView().progressViewStyle(CircularProgressViewStyle())
                                } else if let profileImage = profileImage {
                                    Image(uiImage: profileImage)
                                        .resizable().scaledToFill()
                                        .frame(width: 100, height: 100).clipShape(Circle())
                                } else {
                                    // Placeholder
                                    ZStack {
                                        Circle().fill(Color.blue.opacity(0.1)).frame(width: 100, height: 100)
                                        Image(systemName: "person.fill")
                                            .resizable().scaledToFit().padding(24)
                                            .foregroundColor(.blue).frame(width: 100, height: 100)
                                    }
                                }
                            }
                            .frame(width: 100, height: 100) // Ensure consistent frame

                            // Edit Button Overlay
                            Button { showingImagePicker = true } label: {
                                Image(systemName: "camera.circle.fill")
                                    .font(.system(size: 30))
                                    .symbolRenderingMode(.multicolor) // Makes inner part white, outer blue
                                    .background(Circle().fill(.background)) // Background circle for contrast
                                    .shadow(radius: 2)
                            }
                            .offset(x: 10, y: 10) // Adjust offset slightly
                        } // End ZStack for Profile Image

                        // Username
                        Text(authManager.currentUser?.username ?? "Water Hero")
                            .font(.title2).fontWeight(.bold)

                        // Member Since
                        Text("Member since \(formattedDate(authManager.currentUser?.dateJoined ?? Date()))")
                            .font(.subheadline).foregroundColor(.secondary)

                    } // End Profile Header VStack
                    .frame(maxWidth: .infinity) // Take full width
                    .padding()
                    .background(Color(.systemBackground)) // Use adaptive background
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)

                    // User Statistics Section (Simplified from Map)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("My Contributions")
                            .font(.headline)

                        if let user = authManager.currentUser {
                             HStack(spacing: 0) { // Use spacing 0 and add padding within cards
                                 StatCard(icon: "mappin.and.ellipse", value: "\(user.stationsAdded)", label: "Stations Added")
                                 Divider().frame(height: 40).padding(.horizontal, 8)
                                 StatCard(icon: "heart.text.square", value: "\(user.favoriteStations.count)", label: "Favorites")
                                 // Add Reviews count if available
                                 // Divider().frame(height: 40).padding(.horizontal, 8)
                                 // StatCard(icon: "star.bubble", value: "\(user.reviewsWritten ?? 0)", label: "Reviews")
                             }
                             .padding(.vertical, 8) // Add vertical padding to the container
                             .background(Color.blue.opacity(0.1))
                             .cornerRadius(10)
                         } else {
                             Text("Sign in to see your contributions.")
                                 .foregroundColor(.secondary)
                         }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)

                    // Impact Statistics Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Impact")
                            .font(.headline)

                        if let user = authManager.currentUser, user.stationsAdded > 0 {
                             let bottlesSaved = user.stationsAdded * 30 // Rough estimate

                             HStack(spacing: 16) { // Ensure spacing between cards
                                 StatCard(icon: "trash.slash.fill", value: "\(bottlesSaved)", label: "Bottles Saved")
                                 StatCard(icon: "leaf.fill", value: "\(Int(Double(bottlesSaved) * 0.082))kg", label: "CO₂ Saved") // Use CO₂ symbol
                             }
                             HStack { // Add informational text
                                 Image(systemName: "info.circle").foregroundColor(.secondary)
                                 Text("Estimates based on stations added.")
                                     .font(.caption).foregroundColor(.secondary)
                             }.padding(.top, 4)
                         } else {
                             Text("Add stations to see your environmental impact!")
                                 .foregroundColor(.secondary)
                                 .padding()
                         }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)

                    // Settings Section
                    VStack(alignment: .leading, spacing: 0) { // Use spacing 0 for dividers to connect
                         Text("Settings & More").font(.headline).padding([.horizontal, .top]) // Add padding

                         SettingsOptionRow(icon: "gear", text: "App Settings") { showSettingsView = true }
                         Divider().padding(.leading) // Indent divider
                         SettingsOptionRow(icon: "questionmark.circle", text: "Help & FAQ") { /* Action */ }
                         Divider().padding(.leading)
                         SettingsOptionRow(icon: "star", text: "Rate the App") { /* Action */ }
                         Divider().padding(.leading)
                         SettingsOptionRow(icon: "square.and.arrow.up", text: "Share the App") { /* Action */ }
                         Divider().padding(.leading)
                         SettingsOptionRow(icon: "lock.shield", text: "Privacy Policy") { /* Action */ }
                         Divider().padding(.leading)
                         SettingsOptionRow(icon: "doc.text", text: "Terms of Service") { /* Action */ }

                     }
                     .padding(.bottom) // Add bottom padding
                     .background(Color(.systemBackground))
                     .cornerRadius(12)
                     .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)

                    // Sign Out Button
                    Button(role: .destructive) { // Use destructive role for sign out
                         authManager.signOut { success, _ in
                             if success { dismiss() }
                             // Handle sign out failure? Maybe show alert?
                         }
                     } label: {
                         Text("Sign Out")
                             .fontWeight(.medium) // Make text slightly bolder
                             .padding()
                             .frame(maxWidth: .infinity) // Full width
                             .background(Color(.systemGray6)) // Use adaptive gray
                             .foregroundColor(.red)
                             .cornerRadius(10)
                     }
                     .padding(.top, 10) // Space above sign out button

                } // End main VStack
                .padding() // Padding around the entire scroll view content
            } // End ScrollView
            .navigationTitle("Profile") // Set title if using NavigationView
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { // Add a "Done" button to the navigation bar
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss() // This will dismiss the ProfileView if presented as a sheet
                    }
                }
            }
            .sheet(isPresented: $showSettingsView) {
                // Pass only necessary environment objects/bindings
                 SettingsViewSheet(isPresented: $showSettingsView)
                     // .environmentObject(authManager) // Settings might not need authManager directly
             }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $inputImage) // Use the simpler struct name
            }
            .onChange(of: inputImage) { _, newImage in // Use new Swift syntax
                guard let newImage = newImage else { return }
                profileImage = newImage // Show selected image immediately
                uploadProfileImage(newImage) // Start upload
            }
            .alert(isPresented: $showAlert) { // Standard alert
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        } // End NavigationView
        .onAppear {
            // Load initial data when the view appears
            if authManager.currentUser != nil {
                loadProfileImage() // Load image if user exists
                // Load user stations if needed for this view
                // stationsViewModel.loadUserStations(userId: userId)
            }
        }
    } // End body

    // Format date helper
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // Load profile image function (Corrected)
    private func loadProfileImage() {
         guard let user = authManager.currentUser else { return }
         // Check UserDefaults for a saved profile image URL/path
         if let savedImageUrlOrPath = UserDefaults.standard.string(forKey: "profileImageUrl"), !savedImageUrlOrPath.isEmpty {
             print("Loading profile image from UserDefaults: \(savedImageUrlOrPath)")
             isLoadingImage = true
             FirebaseManager.shared.downloadProfilePhoto(profileImageUrlOrPath: savedImageUrlOrPath) { result in
                 DispatchQueue.main.async {
                     self.isLoadingImage = false
                     switch result {
                     case .success(let image):
                         print("Successfully loaded profile image from UserDefaults")
                         self.profileImage = image
                     case .failure(let error):
                         print("Failed to load profile image from UserDefaults: \(error.localizedDescription)")
                         // If loading from UserDefaults fails, try loading from currentUser (if available)
                         if let imageUrlOrPath = user.profileImageUrl, !imageUrlOrPath.isEmpty, imageUrlOrPath != savedImageUrlOrPath {
                             self.loadImageFromCurrentUser(imageUrlOrPath: imageUrlOrPath)
                         } else {
                             self.profileImage = nil
                         }
                     }
                 }
             }
         } else if let imageUrlOrPath = user.profileImageUrl, !imageUrlOrPath.isEmpty {
             // If no saved URL in UserDefaults, try loading from currentUser
             loadImageFromCurrentUser(imageUrlOrPath: imageUrlOrPath)
         } else {
             self.profileImage = nil // Show placeholder
         }
     }

    private func loadImageFromCurrentUser(imageUrlOrPath: String) {
        print("Loading profile image from currentUser: \(imageUrlOrPath)")
        isLoadingImage = true
        FirebaseManager.shared.downloadProfilePhoto(profileImageUrlOrPath: imageUrlOrPath) { result in
            DispatchQueue.main.async {
                self.isLoadingImage = false
                switch result {
                case .success(let image):
                    print("Successfully loaded profile image from currentUser")
                    self.profileImage = image
                case .failure(let error):
                    print("Failed to load profile image from currentUser: \(error.localizedDescription)")
                    self.profileImage = nil
                }
            }
        }
    }


     // Upload profile image function (Corrected - call new FirebaseManager func)
     private func uploadProfileImage(_ image: UIImage) {
         guard let userId = authManager.currentUser?.id else {
             alertTitle = "Error"; alertMessage = "User not logged in"; showAlert = true
             return
         }

         isLoadingImage = true
         print("Starting profile image upload for user: \(userId)")

         // Use the corrected FirebaseManager upload function
         FirebaseManager.shared.uploadProfilePhoto(userId: userId, image: image) { result in
             DispatchQueue.main.async {
                 self.isLoadingImage = false
                 switch result {
                 case .success(let urlOrPath): // Function now returns URL or path on success
                     print("Successfully uploaded profile image. Path/URL: \(urlOrPath)")
                     // Update the local user model's image URL/path immediately
                     self.authManager.currentUser?.profileImageUrl = urlOrPath
                     // Refresh the image view (though it should already show the preview)
                     self.profileImage = image
                     // Save the profile image URL/path to UserDefaults
                     UserDefaults.standard.set(urlOrPath, forKey: "profileImageUrl")
                 case .failure(let error):
                     print("Failed to upload profile image: \(error.localizedDescription)")
                     self.alertTitle = "Upload Failed"
                     self.alertMessage = error.localizedDescription
                     self.showAlert = true
                      // Revert displayed image to previous one if upload fails? Or keep new one?
                      // Let's keep the newly selected one for now.
                 }
             }
         }
     }

} // End struct ProfileView

// Individual Stat Card (Modified for flexibility)
struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) { // Reduced spacing
            Image(systemName: icon)
                .font(.system(size: 24)) // Slightly smaller icon
                .foregroundColor(.blue)

            Text(value)
                .font(.title2) // Slightly smaller value text
                .fontWeight(.bold)
                .lineLimit(1) // Prevent wrapping
                .minimumScaleFactor(0.8) // Allow shrinking

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2) // Allow label to wrap slightly

        }
        .frame(maxWidth: .infinity, minHeight: 80) // Ensure consistent height
        .padding(.horizontal, 4) // Reduced horizontal padding
         // Background moved to the container (HStack in ProfileView)
    }
}

// Settings Row (Simplified using Button)
struct SettingsOptionRow: View {
    let icon: String
    let text: String
    let action: () -> Void // Action to perform on tap

    var body: some View {
        Button(action: action) { // Make the whole row tappable
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 25, alignment: .center) // Align icons

                Text(text)
                    .foregroundColor(.primary) // Use primary text color

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5)) // Make chevron less prominent
            }
            .padding(.vertical, 12) // Standard padding
            .padding(.horizontal) // Add horizontal padding
        }
    }
}


// Settings View (Sheet) - No changes needed here unless requirements changed
struct SettingsViewSheet: View {
    // @EnvironmentObject var authManager: AuthManager // Removed if not needed
    @Binding var isPresented: Bool
    @AppStorage("isDarkMode") private var isDarkMode = false

    @State private var defaultRadius: Double = 1.0 // Example setting
    @State private var notificationsEnabled = true // Example setting

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
                    // Conditional toggles...
                }

                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $isDarkMode)
                }

                Section("About") {
                    HStack { Text("Version"); Spacer(); Text("1.0.1").foregroundColor(.secondary) } // Example version
                    Button("Contact Support") { /* Action */ }
                    Button("Privacy Policy") { /* Action */ }
                    Button("Terms of Service") { /* Action */ }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
}

// Image Picker (Keep as is)
struct ImagePicker: UIViewControllerRepresentable {
     @Binding var image: UIImage?
     @Environment(\.presentationMode) private var presentationMode // Use presentationMode

     func makeUIViewController(context: Context) -> UIImagePickerController {
         let picker = UIImagePickerController()
         picker.delegate = context.coordinator
         picker.allowsEditing = true // Allow editing
         return picker
     }

     func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

     func makeCoordinator() -> Coordinator {
         Coordinator(self)
     }

     class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
         let parent: ImagePicker

         init(_ parent: ImagePicker) {
             self.parent = parent
         }

         func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
             // Prioritize edited image
             if let editedImage = info[.editedImage] as? UIImage {
                 parent.image = editedImage
             } else if let originalImage = info[.originalImage] as? UIImage {
                 parent.image = originalImage
             }
             parent.presentationMode.wrappedValue.dismiss()
         }

         func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
             parent.presentationMode.wrappedValue.dismiss()
         }
     }
}


#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared) // Ensure AuthManager for preview
}
