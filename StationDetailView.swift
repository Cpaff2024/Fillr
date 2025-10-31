import SwiftUI
import CoreLocation
import MapKit // Needed for MKMapItem

struct StationDetailView: View {
    // Inputs
    let station: RefillStation
    let getPhoto: (String, @escaping (UIImage?) -> Void) -> Void

    // Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var reviewsManager = ReviewsManager() // For reviews shown on this page

    // State
    @State private var photos: [UIImage] = []
    @State private var loadingPhotos = false
    @State private var isFavorite = false
    @State private var isTogglingFavorite = false
    @State private var showingReviewSheet = false // Sheet for writing/editing review
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingDirections = false // Not used directly currently
    @State private var directionsTransport: DirectionsTransportType = .walking

    // --- State for Refill Logging ---
    @State private var isLoggingRefill = false // To disable button during async operation
    @State private var showLogConfirmation = false // To show simple confirmation message
    // --- End Refill Logging State ---

    // Enum for Directions
    enum DirectionsTransportType {
        case walking, driving, transit
        var mapLaunchOption: String {
            switch self {
            case .walking: return MKLaunchOptionsDirectionsModeWalking
            case .driving: return MKLaunchOptionsDirectionsModeDriving
            case .transit: return MKLaunchOptionsDirectionsModeTransit
            }
        }
        var icon: String {
            switch self {
            case .walking: return "figure.walk"
            case .driving: return "car.fill"
            case .transit: return "bus.fill"
            }
        }
        var title: String {
            switch self {
            case .walking: return "Walking"
            case .driving: return "Driving"
            case .transit: return "Transit"
            }
        }
    }

    var body: some View {
        // Use NavigationView to embed ScrollView and provide toolbar
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Photos section (Keep existing)
                    photoSection

                    // Main content padding
                    VStack(alignment: .leading, spacing: 12) {
                        headerSection // Name and Favorite Button
                        detailsSection // Type, Cost, etc.
                        Divider().padding(.vertical, 4)
                        descriptionSection // Description and Limitations
                        reviewSection // Review summary and button
                        Divider().padding(.vertical, 4)

                        // --- Log Refill Section (New) ---
                        logRefillSection
                        Divider().padding(.vertical, 4)
                        // --- End Log Refill Section ---

                        dateAddedSection // Date Added
                        directionsSection // Get Directions Buttons
                    }
                    .padding(.horizontal) // Apply horizontal padding to content below photos
                }
            }
            // Modifiers for the ScrollView or outer VStack if needed
            .navigationTitle(station.name) // Use station name as title
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadPhotos()
                checkIfFavorite()
                reviewsManager.fetchReviews(for: station.id.uuidString, currentUserId: authManager.currentUser?.id)
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: $showingReviewSheet) {
                // Pass necessary environment objects if WriteReviewView needs them
                WriteReviewView(
                    stationId: station.id.uuidString,
                    reviewToEdit: reviewsManager.userReview, // Pass potential review to edit
                    onSave: { review in handleReviewSave(review) } // Use helper function
                )
                .environmentObject(authManager) // Pass AuthManager
            }
        }
        // Apply alert modifier to the NavigationView itself
         .alert(alertTitle, isPresented: $showAlert) {
              Button("OK") { }
          } message: {
              Text(alertMessage)
          }
    } // End body

    // MARK: - Computed View Properties (for clarity)

    @ViewBuilder private var photoSection: some View {
        if !station.photoIDs.isEmpty {
            TabView {
                if photos.isEmpty && loadingPhotos {
                    loadingPlaceholder
                } else if photos.isEmpty {
                    noPhotosPlaceholder
                } else {
                    ForEach(0..<photos.count, id: \.self) { index in
                        Image(uiImage: photos[index])
                            .resizable()
                            .scaledToFill()
                            .frame(height: 240) // Keep fixed height for consistency
                            .clipped() // Clip image to bounds
                    }
                }
            }
            .frame(height: 240)
            .tabViewStyle(.page(indexDisplayMode: .automatic)) // Show page dots
            .background(Color(.secondarySystemBackground)) // Background for tab view area
        } else {
             // Optional: Show a placeholder if there are NO photo IDs
             ZStack {
                 Rectangle()
                     .fill(Color(.secondarySystemBackground))
                     .frame(height: 240)
                 Image(systemName: "photo.on.rectangle.angled")
                     .font(.system(size: 60))
                     .foregroundColor(.secondary)
                 Text("No Photos Available")
                     .font(.caption)
                     .foregroundColor(.secondary)
                     .padding(.top, 80) // Adjust position
             }
        }
    }

    private var loadingPlaceholder: some View {
        ZStack {
            Rectangle().fill(Color(.secondarySystemBackground)).frame(height: 240)
            ProgressView().scaleEffect(1.5)
        }
    }

    private var noPhotosPlaceholder: some View {
        ZStack {
            Rectangle().fill(Color(.secondarySystemBackground)).frame(height: 240)
            Image(systemName: "photo").font(.largeTitle).foregroundColor(.secondary)
        }
    }

    private var headerSection: some View {
        HStack {
            Text(station.name).font(.title).bold().lineLimit(2) // Allow wrapping
            Spacer()
            Button(action: toggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundColor(isFavorite ? .red : .gray)
                    .padding(8)
                    .background(.thinMaterial, in: Circle()) // Use material background
                    .shadow(radius: 2)
                    .overlay(isTogglingFavorite ? ProgressView().tint(.blue) : nil) // Simplified overlay
            }
            .disabled(isTogglingFavorite || authManager.currentUser == nil)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) { // Use VStack for vertical layout
            Label(station.locationType.rawValue, systemImage: station.locationType.icon)
                .foregroundColor(.secondary)
            Text(station.cost.rawValue)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(station.cost.backgroundColor) // Ensure background is applied
                .foregroundColor(.primary) // Ensure text color contrasts
                .clipShape(Capsule()) // Use Capsule shape

             // Add Car Accessible Info if available
             if let isCarAccessible = station.isCarAccessible {
                  Label(isCarAccessible ? "Car Accessible" : "Not Easily Car Accessible",
                        systemImage: isCarAccessible ? "car.fill" : "figure.walk")
                       .font(.subheadline)
                       .foregroundColor(.secondary)
             }
        }
    }

    @ViewBuilder private var descriptionSection: some View {
        // Only show section if description or limitations exist
        if !station.description.isEmpty || !station.limitations.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if !station.description.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description").font(.headline)
                        Text(station.description).foregroundColor(.secondary)
                    }
                }
                if !station.limitations.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Limitations").font(.headline)
                        Text(station.limitations).foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Reviews").font(.headline)
                Spacer()
                // Display average rating using StarRatingView
                if reviewsManager.ratingsCount > 0 {
                    HStack(spacing: 4) {
                        StarRatingView(rating: reviewsManager.averageRating, size: 14)
                        Text("(\(reviewsManager.ratingsCount))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No reviews yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // NavigationLink or Button to show reviews (Optional - if you have a separate reviews list view)
            // NavigationLink("View All Reviews", destination: StationReviewsView(stationId: station.id.uuidString))

            // Leave/Edit Review Button
            Button(action: {
                guard authManager.currentUser != nil else {
                    alertTitle = "Sign In Required"
                    alertMessage = "Please sign in to leave a review."
                    showAlert = true
                    return
                }
                showingReviewSheet = true
            }) {
                HStack {
                    Image(systemName: reviewsManager.userReview != nil ? "pencil.circle.fill" : "star.bubble")
                    Text(reviewsManager.userReview != nil ? "Edit Your Review" : "Leave a Review")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10) // Adjust padding
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8) // Standard corner radius
            }
            .buttonStyle(.plain) // Ensure button doesn't have extra styling
            .padding(.vertical, 4)
        }
        .padding(.vertical, 4)
    }


    // --- New Log Refill Button Section ---
    private var logRefillSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Used this Station?").font(.headline)

            Button(action: logRefillAction) {
                HStack {
                    if isLoggingRefill {
                        ProgressView()
                            .tint(.white) // Make spinner white
                            .padding(.trailing, 4)
                    } else if showLogConfirmation {
                         Image(systemName: "checkmark.circle.fill")
                             .foregroundColor(.white) // Keep checkmark white
                    } else {
                         Image(systemName: "drop.fill") // Use drop icon
                              .foregroundColor(.white) // Keep icon white
                    }
                    Text(isLoggingRefill ? "Logging..." : (showLogConfirmation ? "Refill Logged!" : "Log My Refill"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(showLogConfirmation ? Color.green : Color.orange) // Change color on confirmation
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(isLoggingRefill || showLogConfirmation || authManager.currentUser == nil) // Disable during/after logging or if logged out
            .padding(.vertical, 4)

             // Optional: Add text explaining the action
             Text("Tap above each time you refill here to track your personal impact.")
                 .font(.caption)
                 .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    // --- End New Log Refill Button Section ---


    private var dateAddedSection: some View {
        Text("Station added \(formattedDate(station.dateAdded))")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    private var directionsSection: some View {
        VStack(spacing: 10) {
            Text("Get Directions").font(.headline).padding(.top, 8)
            HStack(spacing: 12) {
                ForEach([DirectionsTransportType.walking, .driving, .transit], id: \.self) { mode in
                    Button(action: {
                        directionsTransport = mode
                        openInMaps()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: mode.icon).font(.system(size: 24))
                            Text(mode.title).font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding(.top, 8)
    }


    // MARK: - Helper Functions

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func loadPhotos() {
        guard !station.photoIDs.isEmpty else { return }
        loadingPhotos = true
        photos = [] // Clear existing photos before loading
        let photoIDsToLoad = station.photoIDs // Capture current IDs

        Task { // Use Task for async operations
            var loaded: [UIImage] = []
            for photoID in photoIDsToLoad {
                // Use await with a custom async wrapper or keep completion handler
                 await withCheckedContinuation { continuation in
                     getPhoto(photoID) { image in
                         if let img = image {
                             loaded.append(img)
                         }
                         continuation.resume()
                     }
                 }
            }
            // Update state on main thread after all photos attempted
            DispatchQueue.main.async {
                 self.photos = loaded
                 self.loadingPhotos = false
                 print("DEBUG: Loaded \(loaded.count)/\(photoIDsToLoad.count) photos.")
            }
        }
    }


    private func checkIfFavorite() {
        guard let user = authManager.currentUser else { isFavorite = false; return }
        isFavorite = user.favoriteStations.contains(station.id.uuidString)
    }

    private func toggleFavorite() {
        guard authManager.currentUser != nil else {
            alertTitle = "Not Logged In"
            alertMessage = "Please log in to save favorites."
            showAlert = true
            return
        }

        isTogglingFavorite = true
        let targetStationId = station.id.uuidString

        if isFavorite {
            authManager.removeFromFavorites(stationId: targetStationId) { success, message in
                handleFavoriteToggleResult(success: success, message: message, isAdding: false)
            }
        } else {
            authManager.addToFavorites(stationId: targetStationId) { success, message in
                handleFavoriteToggleResult(success: success, message: message, isAdding: true)
            }
        }
    }

    private func handleFavoriteToggleResult(success: Bool, message: String?, isAdding: Bool) {
         DispatchQueue.main.async { // Ensure UI updates are on main thread
             isTogglingFavorite = false
             if success {
                 isFavorite = isAdding // Update local state to match backend action
             } else {
                 alertTitle = "Error"
                 alertMessage = message ?? "Failed to update favorites."
                 showAlert = true
                 // Revert optimistic UI update if needed, though AuthManager should handle it
             }
         }
     }

     // Handle saving a review (called by WriteReviewView's onSave)
    private func handleReviewSave(_ review: StationReview) {
        Task { // Use Task for async Firestore operations
            let isUpdating = reviewsManager.userReview != nil // Check if we are updating
            let success: Bool

            if isUpdating {
                 success = await reviewsManager.updateReview(review: review)
            } else {
                 success = await reviewsManager.postReview(review: review)
            }

            // Update UI based on result
            DispatchQueue.main.async {
                 if success {
                     showingReviewSheet = false // Close sheet on success
                     // Optionally show a success toast/message
                 } else {
                     alertTitle = "Review Error"
                     alertMessage = reviewsManager.errorMessage ?? "Failed to save review."
                     showAlert = true
                     // Keep sheet open? Or dismiss? User choice.
                     // showingReviewSheet = false
                 }
             }
        }
     }


    // --- New Action Function for Logging Refill ---
    private func logRefillAction() {
         guard let userId = authManager.currentUser?.id else {
             alertTitle = "Not Logged In"
             alertMessage = "Please log in to log your refill."
             showAlert = true
             return
         }

         // Prevent multiple clicks while processing
         guard !isLoggingRefill else { return }
         isLoggingRefill = true

         // Assume standard refill size for simplicity (e.g., 0.5L)
         // Or present UI to ask user for amount
         let refillAmountLitres: Double = 0.5

         // Call AuthManager function which calls FirebaseManager
         authManager.logPersonalRefill(litres: refillAmountLitres) { success, message in
             // Update UI on main thread
             DispatchQueue.main.async {
                 isLoggingRefill = false // Re-enable button
                 if success {
                     print("✅ Refill logged successfully via AuthManager for user \(userId)")
                     // Show confirmation state on button
                     withAnimation {
                         showLogConfirmation = true
                     }
                     // Reset confirmation after a delay
                     DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                          withAnimation {
                              showLogConfirmation = false
                          }
                     }
                 } else {
                      print("🔴 Refill logging failed via AuthManager: \(message ?? "Unknown error")")
                      alertTitle = "Log Refill Failed"
                      alertMessage = message ?? "Could not log refill. Please try again."
                      showAlert = true
                 }
             }
         }
     }
     // --- End New Action Function ---


    private func openInMaps() {
        guard let coordinate = station.coordinate else {
            print("🔴 Error: Station coordinate is nil, cannot open in Maps.")
            alertTitle = "Location Missing"
            alertMessage = "Cannot get directions because location data is missing for this station."
            showAlert = true
            return
        }
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = station.name
        // Open using selected transport type
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: directionsTransport.mapLaunchOption
        ])
    }

} // End struct StationDetailView

// Preview needs adjustment if dependencies changed significantly
// Ensure getPhoto provides a placeholder or handles nil
#Preview {
     // Create a sample station
     let sampleStation = RefillStation(
         id: UUID(),
         coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
         name: "Preview Station",
         description: "A sample station description.",
         locationType: .cafe,
         cost: .purchaseRequired,
         limitations: "During opening hours",
         photoIDs: ["sample1", "sample2"], // Sample photo IDs
         dateAdded: Date(),
         addedByUserID: "user123",
         averageRating: 4.2,
         ratingsCount: 5,
         isCarAccessible: true,
         isDraft: false,
         manualAddress: nil,
         manualDescription: nil
     )

     return StationDetailView(
         station: sampleStation,
         getPhoto: { id, completion in
             // Simulate async photo loading for preview
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                 // Return a placeholder image or nil
                 completion(UIImage(systemName: "photo")) // Placeholder SF Symbol
             }
         }
     )
     .environmentObject(AuthManager.shared) // Provide shared AuthManager for preview
}
