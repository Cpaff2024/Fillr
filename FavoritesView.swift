import SwiftUI
import CoreLocation

struct FavoritesView: View {
    // Authentication manager for favorites
    @EnvironmentObject private var authManager: AuthManager
    
    // ViewModel for loading station data
    @StateObject private var stationsViewModel = RefillStationsViewModel()
    
    // State for a selected station
    @State private var selectedStation: RefillStation?
    
    // Loading and error state
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    // Loading view
                    ProgressView("Loading favorites...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if let error = errorMessage {
                    // Error view
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text(error)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else if stationsViewModel.favoriteStations.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 70))
                            .foregroundColor(.gray)
                        
                        Text("No Favorites Yet")
                            .font(.title2)
                            .bold()
                        
                        Text("Save your favorite water refill stations here for quick access.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding()
                        
                        Button(action: {
                            // Dismiss and go back to the map to add favorites
                        }) {
                            Text("Explore Stations")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.top)
                    }
                    .padding()
                } else {
                    // List of favorites
                    List {
                        ForEach(stationsViewModel.favoriteStations) { station in
                            Button(action: {
                                selectedStation = station
                            }) {
                                StationRow(station: station)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .swipeActions {
                                Button(role: .destructive) {
                                    removeFromFavorites(station: station)
                                } label: {
                                    Label("Remove", systemImage: "heart.slash")
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Favorites")
            .onAppear {
                loadFavorites()
            }
            .onChange(of: authManager.currentUser?.id) { oldValue, newValue in
                // Reload when favorites change
                loadFavorites()
            }
            .sheet(item: $selectedStation) { station in
                StationDetailView(
                    station: station,
                    getPhoto: { photoID, completion in
                        stationsViewModel.getPhoto(for: photoID, completion: completion)
                    }
                )
                .environmentObject(authManager)
            }
        }
    }
    
    // Load the user's favorite stations
    private func loadFavorites() {
        guard let user = authManager.currentUser, !user.favoriteStations.isEmpty else {
            // Empty favorites or not logged in
            stationsViewModel.favoriteStations = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Load stations from Firestore
        Task {
            do {
                let stations: [RefillStation] = []
                // In a real implementation, you would load favorite stations from Firestore here
                // For now, we'll just use an empty array to fix compilation errors
                
                DispatchQueue.main.async {
                    isLoading = false
                    stationsViewModel.favoriteStations = stations
                    
                    if stations.isEmpty {
                        errorMessage = "No favorite stations found."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Error loading favorites: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Remove a station from favorites
    private func removeFromFavorites(station: RefillStation) {
        guard let userId = authManager.currentUser?.id else { return }
        
        // Remove from user's favorites in Firestore
        Task {
            // In a real implementation, you would update Firestore here
            // For now, just update the local array
            DispatchQueue.main.async {
                stationsViewModel.favoriteStations.removeAll { $0.id == station.id }
            }
        }
    }
}

// A row for a single station in the list
struct StationRow: View {
    let station: RefillStation
    
    var body: some View {
        HStack(spacing: 16) {
            // Station type icon
            ZStack {
                Circle()
                    .fill(station.cost.markerColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: station.locationType.icon)
                    .font(.system(size: 24))
                    .foregroundColor(station.cost.markerColor)
            }
            
            // Station details
            VStack(alignment: .leading, spacing: 4) {
                // Name
                Text(station.name)
                    .font(.headline)
                
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
                            .foregroundColor(.secondary)
                        
                        Text("(\(station.ratingsCount))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Chevron indicator
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// Preview for development
struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        FavoritesView()
            .environmentObject(AuthManager.shared)
    }
}
