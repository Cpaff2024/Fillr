import SwiftUI
import CoreLocation // Keep if StationRow uses coordinates implicitly

struct FavoritesView: View {
    // Authentication manager for favorites
    @EnvironmentObject private var authManager: AuthManager

    // ViewModel for loading station data
    // NOTE: Consider if this ViewModel should be passed in or if fetching
    // favorite station details needs a different approach.
    // For now, it's used mainly for getPhoto.
    @StateObject private var stationsViewModel = RefillStationsViewModel()

    // State for managing the actual list of favorite stations
    // Fetched based on user's favorite IDs
    @State private var favoriteStationsList: [RefillStation] = []

    // State for a selected station
    @State private var selectedStation: RefillStation?

    // Loading and error state
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                // Background color or style
                Color(.systemGroupedBackground).ignoresSafeArea()

                if isLoading {
                    // Loading view
                    ProgressView("Loading favorites...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1)) // Dim background slightly
                } else if let error = errorMessage, favoriteStationsList.isEmpty { // Only show error if list is empty
                    // Error view
                    VStack(spacing: 15) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text("Error Loading Favorites")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            loadFavoriteStations()
                        }
                        .padding(.top)
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if favoriteStationsList.isEmpty {
                    // Empty state
                    VStack(spacing: 15) {
                        Image(systemName: "heart.slash.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.7))
                        Text("No Favorites Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Tap the heart icon on a station's detail page to save it here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    // List of favorites
                    List {
                        ForEach(favoriteStationsList) { station in
                            // Use Button for tappable row action
                            Button { selectedStation = station } label: {
                                StationRow(station: station) // Use the corrected StationRow
                            }
                            .buttonStyle(.plain) // Use plain style to make whole row tappable
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 16)) // Adjust insets
                            .listRowSeparator(.hidden) // Hide default separators
                            .listRowBackground(Color.clear) // Use clear background for custom row style
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    removeStationFromFavorites(station: station)
                                } label: {
                                    Label("Remove", systemImage: "heart.slash.fill")
                                }
                                .tint(.red) // Set tint for swipe action
                            }
                        }
                    }
                    .listStyle(.plain) // Use plain style for tighter spacing and no extra background
                    .refreshable { // Allow pull-to-refresh
                        loadFavoriteStations()
                    }
                }
            }
            .navigationTitle("Favorites")
            .onAppear {
                // Load initially if the list is empty
                if favoriteStationsList.isEmpty {
                    loadFavoriteStations()
                }
            }
            // Reload when user's favorites array changes in AuthManager
            .onChange(of: authManager.currentUser?.favoriteStations) { _, _ in
                print("Detected change in user's favorite stations. Reloading FavoritesView.")
                loadFavoriteStations()
            }
            .sheet(item: $selectedStation) { station in
                // Present StationDetailView when a station is selected
                StationDetailView(
                    station: station,
                    getPhoto: stationsViewModel.getPhoto // Pass photo loading function
                )
                .environmentObject(authManager) // Pass necessary environment objects
            }
        }
    }

    // Load the user's favorite stations based on IDs
    private func loadFavoriteStations() {
        guard let user = authManager.currentUser, !user.favoriteStations.isEmpty else {
            favoriteStationsList = [] // Clear list if no user or no favorite IDs
            isLoading = false
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        let favoriteIDs = user.favoriteStations

        Task {
            do {
                // Fetch station details from Firestore for each favorite ID
                // This assumes you have a way to fetch multiple stations by ID
                // (You might need to add a function to FirebaseManager for this)
                // For now, simulate fetching or use a placeholder method.

                // Placeholder: Fetching logic needs implementation in FirebaseManager/ViewModel
                // let fetchedStations = try await FirebaseManager.shared.fetchStations(byIDs: favoriteIDs)

                // --- TEMPORARY SIMULATION ---
                // In a real app, replace this with actual Firestore fetching.
                 print("Simulating fetch for favorite IDs: \(favoriteIDs)")
                 let fetchedStations = await simulateFetchStations(byIDs: favoriteIDs)
                 // --- END SIMULATION ---


                // Update UI on the main thread
                await MainActor.run {
                    isLoading = false
                    favoriteStationsList = fetchedStations.sorted { $0.name < $1.name } // Sort alphabetically
                    if favoriteStationsList.isEmpty && !favoriteIDs.isEmpty {
                        // Handle case where IDs exist but fetch failed or returned nothing
                        errorMessage = "Could not load details for favorite stations."
                    }
                }
            } catch {
                // Handle errors on the main thread
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Error loading favorites: \(error.localizedDescription)"
                    favoriteStationsList = [] // Clear list on error
                }
            }
        }
    }

    // --- SIMULATION FUNCTION (Replace with real fetch) ---
    private func simulateFetchStations(byIDs ids: [String]) async -> [RefillStation] {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        // Return some dummy stations based on IDs for testing
        return ids.compactMap { id -> RefillStation? in
             guard let uuid = UUID(uuidString: id) else { return nil }
             // Create a dummy station for preview/testing
             return RefillStation(id: uuid, coordinate: CLLocationCoordinate2D(latitude: 51.5 + Double.random(in: -0.01...0.01), longitude: -0.1 + Double.random(in: -0.01...0.01)), name: "Favorite \(id.prefix(4))...", description: "Fetched favorite", locationType: RefillStation.LocationType.allCases.randomElement() ?? .cafe, cost: .free, limitations: "Varies", addedByUserID: "testUser")
         }
    }
    // --- END SIMULATION ---

    // Remove a station from favorites (calls AuthManager)
    private func removeStationFromFavorites(station: RefillStation) {
        print("Attempting to remove favorite: \(station.id.uuidString)")
        authManager.removeFromFavorites(stationId: station.id.uuidString) { success, errorMsg in
            if success {
                print("Successfully removed \(station.id.uuidString) via AuthManager")
                // The onChange modifier reacting to authManager.currentUser.favoriteStations
                // should trigger the reload automatically.
                // Optionally, remove locally for immediate UI update:
                // favoriteStationsList.removeAll { $0.id == station.id }
            } else {
                print("Failed to remove favorite: \(errorMsg ?? "Unknown error")")
                // Optionally show an alert to the user
                errorMessage = "Could not remove favorite: \(errorMsg ?? "Please try again.")"
            }
        }
    }
}

// A row for a single station in the list (Corrected Version)
struct StationRow: View {
    let station: RefillStation

    var body: some View {
        HStack(spacing: 16) {
            // Station type icon
            ZStack {
                Circle()
                    // Use markerColor from LocationType instead of Cost
                    .fill(station.locationType.markerColor.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: station.locationType.icon)
                    .font(.system(size: 24))
                    // Use markerColor from LocationType instead of Cost
                    .foregroundColor(station.locationType.markerColor)
            }

            // Station details
            VStack(alignment: .leading, spacing: 4) {
                // Name
                Text(station.name)
                    .font(.headline)
                    .lineLimit(1) // Ensure name doesn't wrap excessively

                // Type and cost
                HStack {
                    Text(station.locationType.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(station.cost.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Limitations if any
                if !station.limitations.isEmpty {
                    Text(station.limitations)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Rating if available
                if let rating = station.averageRating, station.ratingsCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)

                        Text(String(format: "%.1f", rating))
                            .font(.caption)
                            .fontWeight(.medium) // Slightly emphasize rating number
                            .foregroundColor(.secondary)

                        Text("(\(station.ratingsCount))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 2) // Add slight spacing above rating
                }
            }

            Spacer() // Pushes chevron to the right

            // Chevron indicator (subtle)
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.vertical, 8) // Add vertical padding to the HStack
        .padding(.leading) // Add leading padding (trailing handled by list row inset)
        // Removed background/corner/shadow here - let the List handle row appearance
    }
}

// Preview for development
struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock AuthManager with some favorite IDs for preview
        let mockAuthManager: AuthManager = {
            let manager = AuthManager.shared // Use shared instance if possible
            // Simulate a logged-in user with favorites
            manager.currentUser = User(
                id: "previewUser",
                email: "preview@test.com",
                username: "Previewer",
                dateJoined: Date(),
                profileImageUrl: nil,
                stationsAdded: 2,
                favoriteStations: [UUID().uuidString, UUID().uuidString], // Add some dummy IDs
                isVerified: true
            )
            manager.isAuthenticated = true
            return manager
        }()

        FavoritesView()
            .environmentObject(mockAuthManager) // Provide the mock AuthManager
    }
}
