import SwiftUI
import CoreLocation
import MapKit

struct StationDetailView: View {
    // The station to show details for
    let station: RefillStation
    
    // Function to load photos
    let getPhoto: (String, @escaping (UIImage?) -> Void) -> Void
    
    // Access to the dismiss action to close this screen
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var reviewsManager = ReviewsManager()
    
    // State for loaded photos
    @State private var photos: [UIImage] = []
    @State private var loadingPhotos = false
    
    // State for favorite status
    @State private var isFavorite = false
    @State private var isTogglingFavorite = false
    
    // Review state
    @State private var showingReviewSheet = false
    @State private var rating: Int = 0
    @State private var reviewDescription: String = ""
    
    // Alert state
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // Directions state
    @State private var showingDirections = false
    @State private var directionsTransport: DirectionsTransportType = .walking
    
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
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Photos section (if there are photos)
                    if !station.photoIDs.isEmpty {
                        TabView {
                            if photos.isEmpty && loadingPhotos {
                                // Loading placeholder
                                ZStack {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 240)
                                    
                                    ProgressView()
                                        .scaleEffect(1.5)
                                }
                            } else if photos.isEmpty {
                                // No photos loaded yet placeholder
                                ZStack {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 240)
                                    
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                }
                            } else {
                                // Show the loaded photos
                                ForEach(0..<photos.count, id: \.self) { index in
                                    Image(uiImage: photos[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 240)
                                        .clipped()
                                }
                            }
                        }
                        .frame(height: 240)
                        .tabViewStyle(.page)
                        .indexViewStyle(.page(backgroundDisplayMode: .always))
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Header with station name and favorite button
                        HStack {
                            // Station name
                            Text(station.name)
                                .font(.title)
                                .bold()
                            
                            Spacer()
                            
                            // Favorite button
                            Button(action: toggleFavorite) {
                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundColor(isFavorite ? .red : .gray)
                                    .padding(8)
                                    .background(Color.white.opacity(0.9))
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                    .overlay(
                                        isTogglingFavorite ?
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                            .tint(.blue)
                                        : nil
                                    )
                            }
                            .disabled(isTogglingFavorite || authManager.currentUser == nil)
                        }
                        
                        // Station type with icon
                        Label(station.locationType.rawValue, systemImage: station.locationType.icon)
                            .foregroundColor(.secondary)
                        
                        // Cost badge
                        Text(station.cost.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(station.cost.backgroundColor)
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        // Description (if provided)
                        if !station.description.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Description")
                                    .font(.headline)
                                
                                Text(station.description)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        
                        // Limitations (if provided)
                        if !station.limitations.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Limitations")
                                    .font(.headline)
                                
                                Text(station.limitations)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        
                        // Review section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Reviews")
                                    .font(.headline)
                                
                                Spacer()
                                
                                if let averageRating = station.averageRating, station.ratingsCount > 0 {
                                    HStack(spacing: 4) {
                                        ForEach(1...5, id: \.self) { star in
                                            Image(systemName: star <= Int(averageRating.rounded()) ? "star.fill" : "star")
                                                .foregroundColor(.yellow)
                                                .font(.caption)
                                        }
                                        
                                        Text("(\(station.ratingsCount))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text("No reviews yet")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Leave a review button
                            Button(action: {
                                if authManager.currentUser != nil {
                                    showingReviewSheet = true
                                } else {
                                    alertTitle = "Sign In Required"
                                    alertMessage = "Please sign in to leave a review"
                                    showAlert = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: "star.bubble")
                                    Text(reviewsManager.userReview != nil ? "Edit Your Review" : "Leave a Review")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .padding(.vertical, 4)
                        }
                        .padding(.vertical, 4)
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        // Date added
                        Text("Added \(formattedDate(station.dateAdded))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Directions buttons
                        VStack(spacing: 10) {
                            Text("Get Directions")
                                .font(.headline)
                                .padding(.top, 8)
                            
                            HStack(spacing: 12) {
                                ForEach([DirectionsTransportType.walking, .driving, .transit], id: \.self) { mode in
                                    Button(action: {
                                        directionsTransport = mode
                                        openInMaps()
                                    }) {
                                        VStack(spacing: 4) {
                                            Image(systemName: mode.icon)
                                                .font(.system(size: 24))
                                            
                                            Text(mode.title)
                                                .font(.caption)
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
                    .padding(.horizontal)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Close button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadPhotos()
                checkIfFavorite()
                
                // Load reviews for this station
                reviewsManager.fetchReviews(for: station.id.uuidString, currentUserId: authManager.currentUser?.id)
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showingReviewSheet) {
                if let user = authManager.currentUser {
                    ReviewFormView(
                        stationId: station.id.uuidString,
                        userId: user.id,
                        username: user.username,
                        existingReview: reviewsManager.userReview,
                        onSubmit: { (rating, description) in
                            submitReview(rating: rating, description: description)
                        }
                    )
                }
            }
        }
    }
    
    // Format the date in a nice readable format
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Load the photos for this station
    private func loadPhotos() {
        guard !station.photoIDs.isEmpty else { return }
        
        loadingPhotos = true
        let photoIDs = station.photoIDs
        
        for photoID in photoIDs {
            getPhoto(photoID) { image in
                if let image = image {
                    DispatchQueue.main.async {
                        photos.append(image)
                        
                        if photos.count == photoIDs.count {
                            loadingPhotos = false
                        }
                    }
                }
            }
        }
    }
    
    // Check if this station is in user's favorites
    private func checkIfFavorite() {
        guard let user = authManager.currentUser else { return }
        isFavorite = user.favoriteStations.contains(where: { $0 == station.id.uuidString })
    }
    
    // Toggle favorite status
    private func toggleFavorite() {
        guard let user = authManager.currentUser else {
            alertTitle = "Not Logged In"
            alertMessage = "Please log in to save favorites"
            showAlert = true
            return
        }
        
        isTogglingFavorite = true
        
        if isFavorite {
            // Remove from favorites
            authManager.removeFromFavorites(stationId: station.id.uuidString) { success, message in
                DispatchQueue.main.async {
                    isTogglingFavorite = false
                    
                    if success {
                        isFavorite = false
                    } else if let message = message {
                        alertTitle = "Error"
                        alertMessage = message
                        showAlert = true
                    }
                }
            }
        } else {
            // Add to favorites
            authManager.addToFavorites(stationId: station.id.uuidString) { success, message in
                DispatchQueue.main.async {
                    isTogglingFavorite = false
                    
                    if success {
                        isFavorite = true
                    } else if let message = message {
                        alertTitle = "Error"
                        alertMessage = message
                        showAlert = true
                    }
                }
            }
        }
    }
    
    // Submit a review for this station
    private func submitReview(rating: Int, description: String) {
        guard let user = authManager.currentUser else { return }
        
        Task {
            if let existingReview = reviewsManager.userReview {
                // Update existing review
                var updatedReview = existingReview
                updatedReview.rating = rating
                updatedReview.comment = description
                updatedReview.isEdited = true
                updatedReview.dateUpdated = Date()
                
                let success = await reviewsManager.updateReview(review: updatedReview)
                if !success {
                    DispatchQueue.main.async {
                        alertTitle = "Error"
                        alertMessage = "Failed to update your review"
                        showAlert = true
                    }
                }
            } else {
                // Create new review
                let newReview = StationReview.newReview(
                    stationId: station.id.uuidString,
                    userId: user.id,
                    username: user.username,
                    rating: rating,
                    comment: description
                )
                
                let success = await reviewsManager.postReview(review: newReview)
                if !success {
                    DispatchQueue.main.async {
                        alertTitle = "Error"
                        alertMessage = "Failed to post your review"
                        showAlert = true
                    }
                }
            }
        }
        
        showingReviewSheet = false
    }
    
    // Open the location in Maps app with selected transport mode
    private func openInMaps() {
        let place = MKMapItem(placemark: MKPlacemark(coordinate: station.coordinate))
        place.name = station.name
        
        MKMapItem.openMaps(
            with: [place],
            launchOptions: [
                MKLaunchOptionsDirectionsModeKey: directionsTransport.mapLaunchOption
            ]
        )
    }
}
