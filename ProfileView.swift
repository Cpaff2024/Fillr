import SwiftUI
import UIKit
import PhotosUI

// The extracted components (StatCard, SettingsOptionRow, SettingsViewSheet, ImagePicker)
// are now accessible because they are in the same module (the main target).

struct ProfileView: View {
    // Environment
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var toastManager: ToastManager
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

    // Use properties from the consolidated User model
    private var refillsLogged: Int {
        authManager.currentUser?.personalRefillsLogged ?? 0
    }
    private var co2SavedKg: Int {
        authManager.currentUser?.co2SavedKg ?? 0
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
            // Use the extracted SettingsViewSheet
            .sheet(isPresented: $showSettingsView) { SettingsViewSheet(isPresented: $showSettingsView) }
            // Use the extracted ImagePicker
            .sheet(isPresented: $showingImagePicker) { ImagePicker(image: $inputImage) }
            // Change is now handled by an async Task
            .onChange(of: inputImage, handleImageSelection)
            .alert(alertTitle, isPresented: $showAlert) { Button("OK") {} } message: { Text(alertMessage) }
            .onAppear { // Use onAppear to call async function
                loadProfileImage()
            }
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
                      // Uses extracted StatCard
                      NavigationLink { UserStationsListView().environmentObject(authManager) } label: { StatCard(icon: "mappin.and.ellipse", value: "\(user.stationsAdded)", label: "Stations Added") }.buttonStyle(.plain)
                      Divider().frame(height: 40).padding(.horizontal, 8)
                      // Uses extracted StatCard
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
             if refillsLogged > 0 {
                  HStack(spacing: 16) {
                      // Uses extracted StatCard
                      StatCard(icon: "trash.slash.fill", value: "\(refillsLogged)", label: "Bottles Saved")
                      // Uses extracted StatCard
                      StatCard(icon: "leaf.fill", value: "\(co2SavedKg)kg", label: "CO₂ Saved")
                  }
                  HStack {
                      Image(systemName: "info.circle").foregroundColor(.secondary)
                      Text("Estimates based on your logged refills (\(refillsLogged)).").font(.caption).foregroundColor(.secondary)
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
        .padding().background(Color(.secondarySystemBackground)).cornerRadius(12).shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
    }

    private var navigationLinksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
             if authManager.currentUser?.role == "business" {
                 NavigationLink { BusinessDashboardView().environmentObject(authManager) } label: {
                     // Uses extracted SettingsOptionRow
                     SettingsOptionRow(icon: "briefcase.fill", text: "Business Dashboard")
                 }
                 Divider().padding(.leading)
             }
            
             NavigationLink { DraftStationListView().environmentObject(authManager).environmentObject(locationManager) } label: { SettingsOptionRow(icon: "doc.text.magnifyingglass", text: "Draft Stations") }
             Divider().padding(.leading)
             // Uses extracted SettingsOptionRow
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
         .buttonStyle(.plain).padding(.vertical).background(Color(.secondarySystemBackground)).cornerRadius(12).shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
    }

    private var signOutButton: some View {
         Button(role: .destructive) {
              authManager.signOut { success, _ in if success { dismiss() } else { alertTitle = "Sign Out Failed"; alertMessage = "Failed to sign out."; showAlert = true } }
          } label: {
              Text("Sign Out").fontWeight(.medium).padding().frame(maxWidth: .infinity).background(Color(.systemGray5)).foregroundColor(.red).cornerRadius(10)
          }
          .padding(.top, 10)
    }

    // UPDATED: Now uses Task to upload image
    private func handleImageSelection(_ oldImage: UIImage?, _ newImage: UIImage?) {
        guard let image = newImage else { return }
        profileImage = image
        Task { await uploadProfileImage(image) }
    }

    private func formattedDate(_ date: Date) -> String {
         let formatter = DateFormatter()
         formatter.dateStyle = .medium
         formatter.timeStyle = .none
         return formatter.string(from: date)
     }

    // UPDATED: Now uses Task and async throws function
    private func loadProfileImage() {
        // Only load if current user exists AND has an image path
         guard authManager.currentUser != nil,
               let profilePath = authManager.currentUser?.profileImageUrl,
               !profilePath.isEmpty
         else {
             self.profileImage = nil
             return
         }
         
         isLoadingImage = true
         Task { @MainActor in // Use @MainActor isolation for safe UI updates
             do {
                 let image = try await FirebaseManager.shared.downloadProfilePhoto(profileImageUrlOrPath: profilePath)
                 self.profileImage = image
             } catch {
                 print("🔴 ProfileView: Failed to load profile image: \(error.localizedDescription)")
                 self.profileImage = nil
             }
             self.isLoadingImage = false
         }
     }

    // UPDATED: Now uses Task and async throws function
    private func uploadProfileImage(_ image: UIImage) async {
         guard let userId = authManager.currentUser?.id else {
             toastManager.show(message: "User not logged in.", isError: true)
             return
         }
         
         isLoadingImage = true
         
         do {
             let path = try await FirebaseManager.shared.uploadProfilePhoto(userId: userId, image: image)
             
             // Update AuthManager (which still uses closure-based updateProfile)
             authManager.updateProfile(username: nil, profileImageUrl: path) { success, errorMsg in
                 // This closure is run on the main thread inside the AuthManager's implementation
                 if success {
                     print("✅ ProfileView: Successfully updated profile URL.")
                 } else {
                     self.toastManager.show(message: errorMsg ?? "Failed to update profile URL.", isError: true)
                 }
             }
         } catch {
             print("🔴 ProfileView: Failed to upload profile image: \(error.localizedDescription)")
             self.toastManager.show(message: error.localizedDescription, isError: true)
         }
         
         // This should run last, ensuring UI updates are safe
         await MainActor.run {
             self.isLoadingImage = false
         }
     }
}


#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
        .environmentObject(LocationManager())
        .environmentObject(ToastManager.shared)
}
