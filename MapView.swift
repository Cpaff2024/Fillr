import SwiftUI
import MapKit
import CoreLocation
import Combine

// Define the Map Button Style ViewModifier (keep this if it's not in a separate file)
struct MapButtonStyle: ViewModifier {
    let size: CGFloat = 44
    let iconFont: Font = .title3

    func body(content: Content) -> some View {
        content
            .font(iconFont)
            .foregroundColor(.white) // Changed from .primary for better contrast on blue
            .frame(width: size, height: size)
            .background(Color.blue.opacity(0.8)) // Or your app's accent color
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
    }
}

extension View {
    func mapButtonStyle() -> some View {
        modifier(MapButtonStyle())
    }
}

// MARK: - Extracted Subviews (Updated for ToastManager)

// Extracted View for Map Buttons and Greeting
struct MapControlsOverlay: View {
    // Use @Binding for state vars needed from MapView
    @Binding var showingProfile: Bool
    @Binding var showingFilters: Bool
    @Binding var showingAddStation: Bool
    
    // Toast state is now managed globally
    @EnvironmentObject var toastManager: ToastManager

    @Binding var showGreetingBanner: Bool
    @Binding var greetingMessage: String

    // Environment Objects needed by actions
    @EnvironmentObject var locationManager: LocationManager // Needed for AddStation validation

    var body: some View {
        HStack(alignment: .top) {
            // VStack for vertically stacked buttons
            VStack(alignment: .leading, spacing: 10) {
                // Profile Button
                Button(action: { showingProfile = true }) {
                    Image(systemName: "person.crop.circle.fill")
                        .mapButtonStyle()
                }

                // Filter Button
                Button(action: { showingFilters = true }) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .mapButtonStyle()
                }

                // Add Station Button
                Button(action: {
                    guard locationManager.location?.coordinate != nil else {
                        // Use the global ToastManager
                        toastManager.show(message: "Cannot determine your current location.", isError: true)
                        return
                    }
                    withAnimation { showingAddStation = true }
                }) {
                    Image(systemName: "plus")
                         .mapButtonStyle()
                }
            } // End Button VStack

            // Greeting Banner (conditional display)
            if showGreetingBanner {
                GreetingBannerView(message: greetingMessage)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .padding(.top, 5)
                    .zIndex(1)
            }

            Spacer() // Pushes everything to the leading edge

        } // End Top Controls HStack
        .padding(.horizontal)
        .padding(.top, 50) // Adjust as needed based on device safe area
    }
}

// Extracted View for Loading Indicator (unchanged)
struct LoadingOverlay: View {
    var body: some View {
        ZStack { // Use ZStack to ensure it overlays correctly
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            VStack {
                ProgressView().scaleEffect(1.5).tint(.white)
                Text("Loading stations...").font(.headline).foregroundColor(.white).padding(.top)
            }
        }
    }
}


// MARK: - Main MapView Struct

struct MapView: View {
    // EnvironmentObjects and StateObjects
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var locationManager = LocationManager()
    @StateObject private var stationsViewModel = RefillStationsViewModel()
    
    // NEW: Global Toast Manager
    @StateObject private var toastManager = ToastManager.shared

    // State variables for map interaction
    @State private var searchRadius: Double = 1.0 // Keep for filter view, maybe decouple from loading logic
    @State private var position: MapCameraPosition = .automatic
    // Define a default region (e.g., London) for previews or initial load
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    )

    // State for storing refill stations and selection
    @State private var selectedStation: RefillStation?
    @State private var showingAddStation = false
    @State private var showingProfile = false
    @State private var showingFilters = false

    // Loading and error state
    @State private var errorMessage: String? // For the alert
    @State private var showingError = false // Controls the alert
    // Removed local toast state

    // Debouncing Setup for location AND map region changes
    private let locationUpdatePublisher = PassthroughSubject<CLLocationCoordinate2D, Never>()
    private let regionChangePublisher = PassthroughSubject<MKCoordinateRegion, Never>()
    @State private var cancellables = Set<AnyCancellable>()

    // State for Greeting Banner
    @State private var showGreetingBanner = false
    @State private var greetingMessage = ""

    // Main body of the MapView
    var body: some View {
        ZStack(alignment: .topLeading) { // Main container ZStack

            // --- Use the extracted Map view ---
            mainMapView // <-- UPDATED Map view content

            // --- Overlays ---
            MapControlsOverlay(
                showingProfile: $showingProfile,
                showingFilters: $showingFilters,
                showingAddStation: $showingAddStation,
                showGreetingBanner: $showGreetingBanner,
                greetingMessage: $greetingMessage
            )
            .environmentObject(locationManager)
            .environmentObject(toastManager) // Inject ToastManager

            if stationsViewModel.isLoading {
                LoadingOverlay()
            }
            
            // Use the global ToastOverlay
            ToastOverlay()
                .environmentObject(toastManager)
            // --- End Overlays ---

        } // End Main ZStack
        // --- Modifiers attached to the ZStack ---
        .sheet(isPresented: $showingAddStation, onDismiss: { /* Optional: Reload data? */ }) {
            let coordinateToAdd = locationManager.location?.coordinate ?? region.center
             AddStationView(
                 isPresented: $showingAddStation,
                 coordinate: coordinateToAdd,
                 draftToEdit: nil,
                 onSave: handleAddStationSave
             )
             .environmentObject(locationManager)
             .environmentObject(authManager)
             .environmentObject(toastManager) // Inject ToastManager to AddStationView
         }
        .sheet(item: $selectedStation) { station in
             StationDetailView(
                 station: station,
                 getPhoto: stationsViewModel.getPhoto
             )
             .environmentObject(authManager)
             .environmentObject(toastManager) // Inject ToastManager to DetailView
         }
        .sheet(isPresented: $showingFilters) {
            FilterView(
                selectedLocationTypes: $stationsViewModel.selectedLocationTypes,
                selectedCostTypes: $stationsViewModel.selectedCostTypes,
                isPresented: $showingFilters,
                searchRadius: $searchRadius
            )
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
                .environmentObject(authManager)
                .environmentObject(locationManager)
                .environmentObject(toastManager) // Inject ToastManager
        }
        .alert("Error", isPresented: $showingError, presenting: stationsViewModel.errorMessage ?? errorMessage) { _ in
             Button("OK") {
                 stationsViewModel.errorMessage = nil
                 errorMessage = nil
             }
         } message: { message in
             Text(message)
         }
         .onChange(of: stationsViewModel.errorMessage) { _, newError in
             if newError != nil && !newError!.isEmpty {
                 showingError = true
             }
         }
        // --- End Modifiers ---
    } // End body


    // --- Extracted computed property for the Map view ---
    private var mainMapView: some View {
        Map(position: $position, selection: $selectedStation) {
            UserAnnotation()
                .annotationTitles(.hidden)

            // --- UPDATED: Use Annotation with custom view ---
            ForEach(stationsViewModel.filteredStations) { station in
                if let coord = station.coordinate {
                    Annotation(station.name, coordinate: coord) {
                        // Use the StationMarkerView which now uses locationType colors
                        StationMarkerView(station: station)
                             // Optional: Animate selection slightly
                            .scaleEffect(selectedStation == station ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedStation)
                            .onTapGesture {
                                selectedStation = station
                            }
                    }
                    .tag(station) // Keep tag for selection handling
                    // Removed clustering for simplicity with custom annotations
                    // .clusterIdentifier("stationCluster")
                }
            }
            // --- END UPDATE ---
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControlVisibility(.automatic)
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onAppear(perform: setupInitialMapState)
        .onChange(of: locationManager.location, handleLocationChange)
        .onMapCameraChange(frequency: .continuous) { context in
            regionChangePublisher.send(context.region)
        }
        // Deselect station if map is tapped elsewhere
        .onTapGesture {
             selectedStation = nil
        }
    }


    // MARK: - Helper Functions (UPDATED FOR LOCATION FIX)

    private func setupInitialMapState() {
        // 1. MANDATORY: Request permission and start updates immediately.
        locationManager.requestLocationPermissionAndUpdates()
        
        setupDebouncers() // Setup both debouncers

        let inPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        if inPreview {
            stationsViewModel.loadSampleStations()
            position = .region(region)
            prepareAndShowGreeting()
        }
        // 2. REMOVED: Immediate check of locationManager.location?.coordinate because it's often nil initially.
        // We rely entirely on the onChange handler below to set the initial position/load data when the location becomes available.
        else {
            print("MapView setupInitialMapState: Waiting for actual location.")
            // Temporarily set map position to the default (London) region until location comes through.
            position = .region(region)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { prepareAndShowGreeting() }
        }
    }

    private func handleLocationChange(_ oldLocation: CLLocation?, _ newLocation: CLLocation?) {
        guard let coordinate = newLocation?.coordinate else { return }
        print("MapView handleLocationChange: Location updated - \(coordinate.latitude), \(coordinate.longitude)")

        // NEW LOGIC: Only perform initial load/position update once, when location goes from nil/old default to a real value.
        let isInitialLoad = stationsViewModel.stations.isEmpty && (oldLocation == nil || oldLocation!.coordinate.latitude == 51.5074)

        if isInitialLoad {
            loadStations(center: coordinate, radius: searchRadius)
            position = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
            print("MapView: Initial load and position set to current location.")
        }

        locationUpdatePublisher.send(coordinate)
    }

    private func setupDebouncers() {
        locationUpdatePublisher
            .debounce(for: .seconds(1.5), scheduler: RunLoop.main)
            .sink { coordinate in
                print("MapView Location Debouncer: User location changed significantly. Consider reloading based on new center?")
                // Decide if reloading on user move is desired
                // self.loadStations(center: coordinate, radius: self.searchRadius)
            }
            .store(in: &cancellables)

        regionChangePublisher
            .debounce(for: .seconds(1.0), scheduler: RunLoop.main)
             // Use removeDuplicates to avoid reloading if region hasn't changed meaningfully
            .removeDuplicates { $0.center.latitude == $1.center.latitude && $0.center.longitude == $1.center.longitude && $0.span.latitudeDelta == $1.span.latitudeDelta }
            .sink { newRegion in
                 print("MapView Region Debouncer: Triggering load for region center: \(newRegion.center.latitude), \(newRegion.center.longitude)")
                 // TODO: Calculate radius based on region span for more accuracy?
                 self.loadStations(center: newRegion.center, radius: self.searchRadius) // Using fixed filter radius for now
             }
             .store(in: &cancellables)
     }

    private func loadStations(center: CLLocationCoordinate2D, radius: Double) {
        // Clear selection when reloading stations in a new area
        // selectedStation = nil // Optional: Deselect station on reload
        stationsViewModel.loadNearbyStations(
            center: center,
            radiusInMiles: radius
        )
    }

    private func prepareAndShowGreeting() {
        guard authManager.isAuthenticated, let user = authManager.currentUser else { return }
        let hour = Calendar.current.component(.hour, from: Date())
        let name = user.username.isEmpty ? "Water Hero" : user.username
        var greeting: String

        switch hour {
        case 5..<12: greeting = "Good Morning"
        case 12..<18: greeting = "Good Afternoon"
        default: greeting = "Good Evening"
        }
        greetingMessage = "\(greeting), \(name)!"

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { showGreetingBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.5)) { showGreetingBanner = false }
        }
    }

    private func handleAddStationSave(station: RefillStation, photos: [UIImage]) {
         if photos.isEmpty { toastManager.show(message: "Please add at least one photo", isError: true); return }
         guard let userId = authManager.currentUser?.id else { toastManager.show(message: "You must be logged in to add a station.", isError: true); return }

         var finalStation = station
         finalStation.addedByUserID = userId
         finalStation.isDraft = false

         stationsViewModel.addStation(finalStation, photos: photos) { success, errorMsg in
              if success {
                  toastManager.show(message: "Station added successfully!", isError: false)
                  showingAddStation = false
                   // Optionally reload stations centered on the newly added one?
                   if let newCoord = finalStation.coordinate {
                       loadStations(center: newCoord, radius: searchRadius)
                       // Optionally move map position?
                       // position = .region(MKCoordinateRegion(center: newCoord, span: region.span))
                   }
              } else {
                  toastManager.show(message: errorMsg ?? "Failed to add station.", isError: true)
              }
          }
     }

     // Removed unused local helper showToastMessage
} // End struct MapView


// MARK: - Preview

#Preview {
    MapView()
        .environmentObject(AuthManager.shared)
        .environmentObject(ToastManager.shared)
}
