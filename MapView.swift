import SwiftUI
import MapKit
import CoreLocation
import Combine // Import Combine for debouncing

struct MapView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var locationManager = LocationManager()
    @StateObject private var stationsViewModel = RefillStationsViewModel()

    // State variables for map interaction
    @State private var searchRadius: Double = 1.0 // Default radius is 1 mile
    @State private var position: MapCameraPosition = .automatic
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278), // Default to London
        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    )

    // State for storing refill stations
    @State private var selectedStation: RefillStation?
    @State private var showingAddStation = false
    @State private var showingProfile = false
    @State private var showingFilters = false

    // Loading and error state
    @State private var errorMessage: String? // Holds specific error messages for the alert
    @State private var showingError = false // Controls the alert presentation
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

    // --- Debouncing Setup ---
    // Publisher for location updates
    private let locationUpdatePublisher = PassthroughSubject<CLLocationCoordinate2D, Never>()
    // Cancellable store for Combine subscriptions
    @State private var cancellables = Set<AnyCancellable>()
    // --- End Debouncing Setup ---

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The Map itself
            Map(position: $position, selection: $selectedStation) {
                // Show user's current location blue dot
                UserAnnotation()

                // Display markers for stations from the ViewModel
                ForEach(stationsViewModel.filteredStations) { station in
                    Marker(station.name, coordinate: station.coordinate)
                        .tint(station.cost.markerColor) // Color marker based on cost
                        .tag(station) // Associate the station data with the marker for selection
                }
            }
            .mapStyle(.standard) // Use the standard map style
            .mapControls { // Add standard map controls
                MapUserLocationButton() // Button to center on user location
                MapCompass() // Compass overlay
                MapScaleView() // Scale indicator
            }
            .onAppear { // When the map first appears
                locationManager.requestLocation() // Ask for location permission and start updates
                setupLocationDebouncer() // Setup the debouncer for location updates

                // Handle previews differently from live app
                let inPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
                if inPreview {
                    stationsViewModel.loadSampleStations() // Load fake data for Xcode previews
                    position = .region(region) // Set position for preview
                } else if let initialLocation = locationManager.location?.coordinate {
                    // If location is already available, load stations immediately
                    print("MapView onAppear: Got initial location. Loading stations.") // Diagnostic print
                    stationsViewModel.loadNearbyStations(
                        center: initialLocation,
                        radiusInMiles: searchRadius
                    )
                    // Set initial map position centered on the user
                    position = .region(MKCoordinateRegion(
                        center: initialLocation,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    ))
                } else {
                    // If location isn't available yet, wait for the first update
                    print("MapView onAppear: Initial location not available yet.") // Diagnostic print
                }
            }
             .onChange(of: locationManager.location) { _, newLocation in
                 // When the LocationManager provides a new location...
                 if let coordinate = newLocation?.coordinate {
                     // Send it to the debouncer (don't reload immediately)
                     print("MapView: Location updated - \(coordinate.latitude), \(coordinate.longitude)") // Diagnostic print
                     locationUpdatePublisher.send(coordinate)
                 }
             }
            .onChange(of: searchRadius) { _, newRadius in
                 // When the search radius slider changes...
                if let location = locationManager.location?.coordinate {
                    // Reload stations using the new radius
                    print("MapView: Search radius changed, reloading stations.")
                    stationsViewModel.loadNearbyStations(
                        center: location,
                        radiusInMiles: newRadius
                    )
                }
            }
            // These just trigger re-computation of filteredStations, no reload needed
            .onChange(of: stationsViewModel.selectedLocationTypes) { _, _ in
                 print("Filters changed (Location Types)")
             }
             .onChange(of: stationsViewModel.selectedCostTypes) { _, _ in
                 print("Filters changed (Cost Types)")
             }

            // --- UI Elements Overlay ---
            VStack(alignment: .leading) {
                // Top Left Buttons (Profile, Filter, Add)
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: { showingProfile = true }) {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.white).padding(12)
                            .background(Color.blue).clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                            .frame(width: 24, height: 24)
                    }
                    Spacer()
                    Button(action: { showingFilters = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .foregroundColor(.white).padding(12)
                            .background(Color.blue).clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                            .frame(width: 24, height: 24)
                    }
                    Spacer()
                    Button(action: {
                        // Make sure we have a location before showing the Add screen
                        guard locationManager.location?.coordinate != nil else {
                            toastMessage = "Cannot determine your current location."
                            toastIsError = true
                            withAnimation { showToast = true }
                            return
                        }
                        withAnimation { showingAddStation = true } // Show the AddStationView
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.white).padding(12)
                            .background(Color.blue).clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(.leading, 40) // Increased leading padding
                .padding(.top, 50) // Increased top padding
                .frame(height: 150) // Adjust height as needed to control spacing
            }

            // Toast Message (appears briefly at top)
            if showToast {
                Text(toastMessage)
                    .padding().background(toastIsError ? Color.red.opacity(0.9) : Color.green.opacity(0.9))
                    .foregroundColor(.white).cornerRadius(10).shadow(radius: 3)
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear { // Automatically hide after 3 seconds
                         DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                             withAnimation { showToast = false }
                         }
                     }
            }

            Spacer() // Pushes Add button to bottom (though now it's at the top left)

            // --- Loading Overlay ---
            // Show spinning indicator if ViewModel is loading stations
            if stationsViewModel.isLoading {
                Color.black.opacity(0.4) // Dim background
                    .ignoresSafeArea()
                VStack {
                    ProgressView().scaleEffect(1.5).tint(.white) // Spinner
                    Text("Loading stations...").font(.headline).foregroundColor(.white).padding(.top)
                }
            }

        } // End ZStack (main container)

        // --- Modal Sheets ---
        // Sheet for Adding a Station
        .sheet(isPresented: $showingAddStation) {
            // Use the current location (or default if none) for the new pin
             let coordinateToAdd = locationManager.location?.coordinate ?? region.center
             AddStationView(
                 isPresented: $showingAddStation,
                 coordinate: coordinateToAdd,
                 onSave: { station, photos in // This code runs when AddStationView saves
                     // Basic check: require photos
                     if photos.isEmpty {
                         toastMessage = "Please add at least one photo"
                         toastIsError = true; withAnimation { showToast = true }
                         return // Stop if no photos
                     }
                     // Assign current user ID
                     var newStation = station
                     if let userId = authManager.currentUser?.id { newStation.addedByUserID = userId }
                     else { print("Warning: Adding station without a user ID.") }

                     // Tell the ViewModel to save the station
                     stationsViewModel.addStation(newStation, photos: photos) { success, errorMsg in
                          if success {
                              toastMessage = "Station added successfully!"
                              toastIsError = false
                              showingAddStation = false // Close sheet on success
                          } else {
                              toastMessage = errorMsg ?? "Failed to add station."
                              toastIsError = true
                              showingAddStation = false // Close sheet even on error
                          }
                          // Show the success/failure toast message
                          withAnimation { showToast = true }
                      }
                 }
             )
             .environmentObject(locationManager) // Inject LocationManager here
         }
        // Sheet for Viewing Station Details (when a marker is tapped)
        .sheet(item: $selectedStation) { station in
             StationDetailView(
                 station: station, // Pass the selected station data
                 getPhoto: { photoID, completion in // Pass function to load photos
                     stationsViewModel.getPhoto(for: photoID, completion: completion)
                 }
             )
             .environmentObject(authManager) // Make AuthManager available to detail view
         }
        // Sheet for Filters
        .sheet(isPresented: $showingFilters) {
            FilterView(
                selectedLocationTypes: $stationsViewModel.selectedLocationTypes,
                selectedCostTypes: $stationsViewModel.selectedCostTypes,
                isPresented: $showingFilters,
                searchRadius: $searchRadius // Allow FilterView to change searchRadius
            )
        }
        // Sheet for User Profile
        .sheet(isPresented: $showingProfile) {
            ProfileView()
                .environmentObject(authManager) // Make AuthManager available to profile view
        }

        // --- Alert ---
        // Show an alert if errorMessage (from MapView or ViewModel) has text
        .alert("Error", isPresented: $showingError, presenting: errorMessage ?? stationsViewModel.errorMessage) { _ in
             Button("OK") {
                 // Clear error messages when OK is tapped
                 errorMessage = nil
                 stationsViewModel.errorMessage = nil
             }
         } message: { message in
             Text(message) // Display the error message text
         }
         // Watch for changes in the ViewModel's error message to trigger the alert
         .onChange(of: stationsViewModel.errorMessage) { _, newError in
             if newError != nil {
                 showingError = true // Set state to show the alert
             }
         }

    } // End body

     // --- Debouncer Function ---
     // Sets up the mechanism to delay station reloading after location changes
     private func setupLocationDebouncer() {
         locationUpdatePublisher
             // Wait for 1.5 seconds of no new location updates
             .debounce(for: .seconds(1.5), scheduler: RunLoop.main)
             // When the wait is over, run this code:
             .sink { coordinate in
                 // We are inside a struct, so 'self' is implicitly captured correctly
                 print("MapView: DEBOUNCED location update received. Triggering load for \(coordinate.latitude), \(coordinate.longitude)") // Diagnostic print
                 // Tell the ViewModel to load stations for the new stable location
                 self.stationsViewModel.loadNearbyStations(
                     center: coordinate,
                     radiusInMiles: self.searchRadius
                 )
             }
             .store(in: &cancellables) // Keep track of the subscription
     }
     // --- End Debouncer Function ---

} // End struct MapView

// Xcode Preview setup
#Preview {
    MapView()
        .environmentObject(AuthManager.shared) // Provide AuthManager for preview
}
