import SwiftUI
import UIKit
import PhotosUI

struct ProfileView: View {
    // Environment
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    // State
    @State private var showSettingsView = false
    @State private var showingImagePicker = false
    @State private var inputImage: UIImage?
    @State private var profileImage: UIImage? = nil
    @State private var isLoadingImage = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private var bottlesSaved: Int {
        authManager.currentUser?.personalRefillsLogged ?? 0
    }
    private var co2SavedKg: Int {
        Int(Double(bottlesSaved) * 0.082)
    }

    private var earnedBadges: [Badge] {
        guard let user = authManager.currentUser else { return [] }
        var badges: [Badge] = []
        if user.personalRefillsLogged >= 1 { badges.append(Badges.firstRefill) }
        if user.personalRefillsLogged >= 10 { badges.append(Badges.tenRefills) }
        if user.personalRefillsLogged >= 50 { badges.append(Badges.fiftyRefills) }
        if user.stationsAdded >= 1 { badges.append(Badges.firstStation) }
        if user.stationsAdded >= 5 { badges.append(Badges.fiveStations) }
        if user.stationsAdded >= 10 { badges.append(Badges.tenStations) }
        return badges
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeaderSection
                    myContributionsSection
                    yourImpactSection
                    badgesSection
                    navigationLinksSection
                    signOutButton
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showSettingsView) { SettingsViewSheet(isPresented: $showSettingsView) }
            .sheet(isPresented: $showingImagePicker) { ImagePicker(image: $inputImage) }
            .onChange(of: inputImage, handleImageSelection)
            .alert(alertTitle, isPresented: $showAlert) { Button("OK") {} } message: { Text(alertMessage) }
            .onAppear { if authManager.currentUser != nil { loadProfileImage() } }
        }
    }

    private var profileHeaderSection: some View {
         VStack(spacing: 12) {
             ZStack(alignment: .bottomTrailing) {
                 Group {
                     if isLoadingImage { ProgressView() }
                     else if let img = profileImage { Image(uiImage: img).resizable().scaledToFill() }
                     else { Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().padding(20).foregroundColor(Color(.systemGray3)).background(Color(.systemGray6)) }
                 }
                 .frame(width: 100, height: 100).clipShape(Circle())
                 Button { showingImagePicker = true } label: { Image(systemName: "camera.circle.fill").symbolRenderingMode(.multicolor).font(.system(size: 30)).background(Circle().fill(.background).scaleEffect(1.1)) }.offset(x: 5, y: 5).shadow(radius: 2)
             }
             Text(authManager.currentUser?.username ?? "Water Hero").font(.title2).fontWeight(.bold)
             Text("Member since \(formattedDate(authManager.currentUser?.dateJoined ?? Date()))").font(.subheadline).foregroundColor(.secondary)
         }
         .frame(maxWidth: .infinity).padding().background(Color(.secondarySystemBackground)).cornerRadius(12).shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
    }

    private var myContributionsSection: some View {
         VStack(alignment: .leading, spacing: 10) {
             Text("My Contributions").font(.headline)
             if let user = authManager.currentUser {
                  HStack(spacing: 0) {
                      NavigationLink { UserStationsListView().environmentObject(authManager) } label: { StatCard(icon: "mappin.and.ellipse", value: "\(user.stationsAdded)", label: "Stations Added") }.buttonStyle(.plain)
                      Divider().frame(height: 40).padding(.horizontal, 8)
                      NavigationLink { FavoritesView().environmentObject(authManager) } label: { StatCard(icon: "heart.text.square.fill", value: "\(user.favoriteStations.count)", label: "Favorites") }.buttonStyle(.plain)
                  }
                  .padding(.vertical, 8).background(Color.blue.opacity(0.05)).cornerRadius(10)
              } else { Text("Sign in to see your contributions.").foregroundColor(.secondary) }
         }
         .padding().background(Color(.secondarySystemBackground)).cornerRadius(12).shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
    }

    private var yourImpactSection: some View {
         VStack(alignment: .leading, spacing: 16) {
             Text("Your Personal Impact").font(.headline)
             if bottlesSaved > 0 {
                  HStack(spacing: 16) {
                      StatCard(icon: "trash.slash.fill", value: "\(bottlesSaved)", label: "Bottles Saved")
                      StatCard(icon: "leaf.fill", value: "\(co2SavedKg)kg", label: "CO₂ Saved")
                  }
                  HStack {
                      Image(systemName: "info.circle").foregroundColor(.secondary)
                      Text("Estimates based on your logged refills (\(authManager.currentUser?.personalRefillsLogged ?? 0)).").font(.caption).foregroundColor(.secondary)
                  }.padding(.top, 4)
              } else { Text("Log your refills at stations to see your personal impact!").foregroundColor(.secondary).padding() }
         }
         .padding().background(Color(.secondarySystemBackground)).cornerRadius(12).shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
    }

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Badges").font(.headline)
            let badges = earnedBadges
            if badges.isEmpty {
                Text("Log refills and add stations to earn badges!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(badges) { badge in
                            VStack(spacing: 5) {
                                Image(systemName: badge.iconName)
                                    .font(.system(size: 30))
                                    .foregroundColor(.blue)
                                    .frame(width: 60, height: 60)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                                Text(badge.name)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(height: 30)
                            }
                            .frame(width: 70)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 5)
                }
                .frame(height: 95)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
    }

    private var navigationLinksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
             if authManager.currentUser?.role == "business" {
                 NavigationLink { BusinessDashboardView().environmentObject(authManager) } label: {
                     SettingsOptionRow(icon: "briefcase.fill", text: "Business Dashboard")
                 }
                 Divider().padding(.leading)
             }
            
             NavigationLink { DraftStationListView().environmentObject(authManager).environmentObject(locationManager) } label: { SettingsOptionRow(icon: "doc.text.magnifyingglass", text: "Draft Stations") }
             Divider().padding(.leading)
             Button { showSettingsView = true } label: { SettingsOptionRow(icon: "gear", text: "App Settings") }
             Divider().padding(.leading)
             Button { /* TODO: Action */ } label: { SettingsOptionRow(icon: "questionmark.circle", text: "Help & FAQ") }
             Divider().padding(.leading)
             Button { /* TODO: Action */ } label: { SettingsOptionRow(icon: "star", text: "Rate the App") }
             Divider().padding(.leading)
             Button { /* TODO: Action */ } label: { SettingsOptionRow(icon: "square.and.arrow.up", text: "Share the App") }
             Divider().padding(.leading)
             Button { /* TODO: Action */ } label: { SettingsOptionRow(icon: "lock.shield", text: "Privacy Policy") }
             Divider().padding(.leading)
             Button { /* TODO: Action */ } label: { SettingsOptionRow(icon: "doc.text", text: "Terms of Service") }
         }
         .buttonStyle(.plain)
         .padding(.vertical)
         .background(Color(.secondarySystemBackground)).cornerRadius(12).shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
    }

    private var signOutButton: some View {
         Button(role: .destructive) {
              authManager.signOut { success, _ in if success { dismiss() } else { alertTitle = "Sign Out Failed"; alertMessage = "Failed to sign out."; showAlert = true } }
          } label: {
              Text("Sign Out").fontWeight(.medium).padding().frame(maxWidth: .infinity).background(Color(.systemGray5)).foregroundColor(.red).cornerRadius(10)
          }
          .padding(.top, 10)
    }

    private func handleImageSelection(_ oldImage: UIImage?, _ newImage: UIImage?) {
        guard let image = newImage else { return }
        profileImage = image
        uploadProfileImage(image)
    }

    private func formattedDate(_ date: Date) -> String {
         let formatter = DateFormatter()
         formatter.dateStyle = .medium
         formatter.timeStyle = .none
         return formatter.string(from: date)
     }

    private func loadProfileImage() {
         guard let user = authManager.currentUser, let profilePath = user.profileImageUrl, !profilePath.isEmpty else { self.profileImage = nil; return }
         isLoadingImage = true
         FirebaseManager.shared.downloadProfilePhoto(profileImageUrlOrPath: profilePath) { result in
             DispatchQueue.main.async {
                 self.isLoadingImage = false
                 switch result {
                 case .success(let image): self.profileImage = image
                 case .failure(let error): print("🔴 ProfileView: Failed to load profile image: \(error.localizedDescription)"); self.profileImage = nil
                 }
             }
         }
     }

    private func uploadProfileImage(_ image: UIImage) {
         guard let userId = authManager.currentUser?.id else { alertTitle = "Error"; alertMessage = "User not logged in."; showAlert = true; return }
         isLoadingImage = true
         FirebaseManager.shared.uploadProfilePhoto(userId: userId, image: image) { result in
             DispatchQueue.main.async {
                 self.isLoadingImage = false
                 switch result {
                 case .success(let path):
                     print("✅ ProfileView: Successfully uploaded profile image. Path: \(path)")
                     if self.authManager.currentUser?.profileImageUrl != path { self.authManager.currentUser?.profileImageUrl = path }
                 case .failure(let error):
                     print("🔴 ProfileView: Failed to upload profile image: \(error.localizedDescription)")
                     self.alertTitle = "Upload Failed"; self.alertMessage = error.localizedDescription; self.showAlert = true
                 }
             }
         }
     }
}

// --- HELPER VIEWS ADDED BACK IN ---

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

struct SettingsViewSheet: View {
    @Binding var isPresented: Bool
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("defaultSearchRadius") private var defaultRadius: Double = 1.0
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    var body: some View {
         NavigationView {
             Form {
                 Section("Map Settings") { VStack(alignment: .leading) { Text("Default Search Radius: \(Int(defaultRadius)) mile\(defaultRadius == 1 ? "" : "s")"); Slider(value: $defaultRadius, in: 1...10, step: 1) } }
                 Section("Notifications") { Toggle("Enable Notifications", isOn: $notificationsEnabled) }
                 Section("Appearance") { Toggle("Dark Mode", isOn: $isDarkMode) }
                 Section("About") { HStack { Text("Version"); Spacer(); Text("2.0.1").foregroundColor(.secondary) }; Button("Contact Support") {}; Button("Privacy Policy") {}; Button("Terms of Service") {} }
             }
             .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { isPresented = false } } }
         }
     }
}

struct ImagePicker: UIViewControllerRepresentable {
     @Binding var image: UIImage?
     @Environment(\.presentationMode) private var presentationMode
     func makeUIViewController(context: Context) -> UIImagePickerController { let picker = UIImagePickerController(); picker.delegate = context.coordinator; picker.allowsEditing = true; return picker }
     func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
     func makeCoordinator() -> Coordinator { Coordinator(self) }
     class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
         let parent: ImagePicker; init(_ parent: ImagePicker) { self.parent = parent }
         func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) { if let img = info[.editedImage] as? UIImage { parent.image = img } else if let img = info[.originalImage] as? UIImage { parent.image = img }; parent.presentationMode.wrappedValue.dismiss() }
         func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.presentationMode.wrappedValue.dismiss() }
     }
}


#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
        .environmentObject(LocationManager())
}
