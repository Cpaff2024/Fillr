import SwiftUI
import CoreLocation // Needed for StationRow if it uses coordinates implicitly

struct UserStationsListView: View {
    @EnvironmentObject private var authManager: AuthManager
    // Use a dedicated StateObject for this view's station data
    @StateObject private var stationsViewModel = RefillStationsViewModel()
    @State private var selectedStation: RefillStation?

    var body: some View {
        ZStack {
            // Show loading indicator
            if stationsViewModel.isLoading {
                ProgressView("Loading Your Stations...")
            }
            // Show error message if loading fails
            else if let errorMessage = stationsViewModel.errorMessage, !errorMessage.isEmpty && stationsViewModel.userStations.isEmpty {
                 VStack(spacing: 15) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Error Loading Stations")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            // Show empty state message if no stations added
            else if stationsViewModel.userStations.isEmpty {
                VStack(spacing: 15) {
                    Image(systemName: "mappin.slash.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No Stations Added Yet")
                        .font(.title2)
                        .bold()
                    Text("Stations you add will appear here.")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            // Display the list of user-added stations
            else {
                List {
                    ForEach(stationsViewModel.userStations) { station in
                         // Make row tappable to show detail view
                        Button(action: { selectedStation = station }) {
                            // Reuse the StationRow from FavoritesView if suitable,
                            // or create a dedicated one here.
                            // Assuming StationRow is reusable:
                            StationRow(station: station)
                        }
                         // Style the list rows
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear) // Or use system background
                    }
                }
                .listStyle(.plain) // Use plain style to remove default insets/backgrounds
            }
        }
        .navigationTitle("My Added Stations") // Set title for the view
        .onAppear {
            // Load stations when the view appears
            loadUserStations()
        }
        // Show StationDetailView when a station is selected
        .sheet(item: $selectedStation) { station in
            // Ensure StationDetailView gets the necessary dependencies
            StationDetailView(
                station: station,
                getPhoto: { photoID, completion in
                    stationsViewModel.getPhoto(for: photoID, completion: completion)
                }
            )
            .environmentObject(authManager) // Pass AuthManager
            // If StationDetailView needs RefillStationsViewModel, pass it too
            // .environmentObject(stationsViewModel)
        }
    }

    // Function to load stations added by the current user
    private func loadUserStations() {
        guard let userId = authManager.currentUser?.id else {
            print("User not logged in, cannot load user stations.")
            stationsViewModel.errorMessage = "You must be logged in to see your stations."
            return
        }
        // Call the ViewModel function to load stations for the specific user
        stationsViewModel.loadUserStations(userId: userId)
    }
}

// Add a preview for UserStationsListView
#Preview {
    NavigationView { // Wrap in NavigationView for the title
        UserStationsListView()
            .environmentObject(AuthManager.shared) // Provide shared AuthManager for preview
    }
}
