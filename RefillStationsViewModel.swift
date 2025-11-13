import Foundation
import CoreLocation
import FirebaseFirestore
import SwiftUI // Needed for Published

@MainActor // NEW: Conforming to MainActor guarantees thread safety for @Published properties
class RefillStationsViewModel: ObservableObject {
    // Published properties
    @Published var stations: [RefillStation] = []
    @Published var favoriteStations: [RefillStation] = []
    @Published var userStations: [RefillStation] = []

    @Published var isLoading = false
    @Published var errorMessage: String?

    // Filters
    @Published var selectedLocationTypes: Set<RefillStation.LocationType> = Set(RefillStation.LocationType.allCases)
    @Published var selectedCostTypes: Set<RefillStation.RefillCost> = Set(RefillStation.RefillCost.allCases)
    @Published var showOnlyCarAccessible = false

    // Firebase and Cache
    private lazy var db = Firestore.firestore()
    private var photoCache: [String: UIImage] = [:]

    // Computed property for filtered stations
    var filteredStations: [RefillStation] {
        stations.filter { station in
            guard !station.isDraft else { return false }
            let matchesType = selectedLocationTypes.contains(station.locationType)
            let matchesCost = selectedCostTypes.contains(station.cost)
            let matchesCarAccessibility = showOnlyCarAccessible ? (station.isCarAccessible == true) : true
            return matchesType && matchesCost && matchesCarAccessibility
        }
    }

    // Load Sample Stations (ensure isDraft is false)
    func loadSampleStations() {
         print("DEBUG: Loading sample stations")
         let center = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
         let station1 = RefillStation(id: UUID(), coordinate: CLLocationCoordinate2D(latitude: center.latitude + 0.001, longitude: center.longitude + 0.001), name: "City Park Fountain (Sample)", description: "Public water fountain", locationType: .waterFountain, cost: .free, limitations: "24/7", photoIDs: ["sample1"], dateAdded: Date(), addedByUserID: "user1", listingType: .user, averageRating: 4.5, ratingsCount: 12, isCarAccessible: true, isDraft: false)
         let station2 = RefillStation(id: UUID(), coordinate: CLLocationCoordinate2D(latitude: center.latitude - 0.002, longitude: center.longitude + 0.002), name: "Coffee Bean Cafe (Sample)", description: "Refill for customers", locationType: .cafe, cost: .purchaseRequired, limitations: "7am-7pm", photoIDs: ["sample2"], dateAdded: Date(), addedByUserID: "user2", listingType: .user, averageRating: 3.8, ratingsCount: 5, isCarAccessible: false, isDraft: false)
         stations = [station1, station2]
         print("DEBUG: Loaded \(stations.count) sample stations")
     }

    // Load stations near a location (fetches from Firebase)
    func loadNearbyStations(center: CLLocationCoordinate2D, radiusInMiles: Double) {
        print("DEBUG: ViewModel loadNearbyStations called with center: \(center.latitude), \(center.longitude), radius: \(radiusInMiles)")
        let inPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        if inPreview { loadSampleStations(); return }

        isLoading = true
        errorMessage = nil
        stations = [] // Clear existing stations before fetching

        Task {
            do {
                let fetchedStations = try await FirebaseManager.shared.fetchNearbyStations(center: center, radiusInMiles: radiusInMiles)
                
                // Removed redundant DispatchQueue.main.async block, relying on @MainActor
                self.isLoading = false
                self.stations = fetchedStations
                self.errorMessage = fetchedStations.isEmpty ? "No stations found in your area yet. Be the first to add one!" : nil
                print("DEBUG: Loaded \(self.stations.count) stations from Firebase")
                
            } catch {
                // Removed redundant DispatchQueue.main.async block, relying on @MainActor
                 print("🔴 DEBUG: Error loading stations from Firebase: \(error.localizedDescription)")
                 self.isLoading = false
                 self.errorMessage = "Failed to load stations: \(error.localizedDescription)"
                 self.stations = []
            }
        }
    }

    // Add Station
    func addStation(_ station: RefillStation, photos: [UIImage], completion: @escaping (Bool, String?) -> Void) {
         guard !station.isDraft, station.coordinate != nil else {
             completion(false, "Internal error: Station is a draft or has no coordinates.")
             return
         }
         
         isLoading = true
         errorMessage = nil
         Task {
             do {
                 try await FirebaseManager.shared.saveRefillStation(station, photos: photos, userId: station.addedByUserID)
                 
                 // Removed redundant DispatchQueue.main.async block, relying on @MainActor
                 self.isLoading = false
                 if !self.stations.contains(where: { $0.id == station.id }) {
                      self.stations.append(station)
                 }
                 if !station.addedByUserID.isEmpty && !self.userStations.contains(where: { $0.id == station.id }) {
                     self.userStations.append(station)
                 }
                 completion(true, nil)
                 
             } catch {
                 // Removed redundant DispatchQueue.main.async block, relying on @MainActor
                 print("🔴 DEBUG: Firebase save failed in ViewModel: \(error.localizedDescription)")
                 self.isLoading = false
                 let specificError = error as NSError
                 completion(false, "Failed to save station: \(specificError.localizedDescription)")
             }
         }
     }

    // Load user's stations (for regular users)
    func loadUserStations(userId: String) {
        isLoading = true; errorMessage = nil
        userStations = []
        print("DEBUG: Loading USER-ADDED stations for user: \(userId)")
        
        // Use a Task for async Firestore operation
        Task {
            do {
                let snapshot = try await db.collection("refillStations")
                    .whereField("addedBy", isEqualTo: userId)
                    .whereField("listingType", isEqualTo: ListingType.user.rawValue)
                    .getDocuments()
                
                // Use the FirebaseManager's new parsing helper
                let fetchedStations = snapshot.documents.compactMap { document in
                    FirebaseManager.shared.stationFromFirestoreDocument(document: document, id: document.documentID)
                }
                
                // Removed redundant DispatchQueue.main.async block, relying on @MainActor
                self.isLoading = false
                self.userStations = fetchedStations.sorted { $0.dateAdded > $1.dateAdded }
                print("DEBUG: Parsed \(self.userStations.count) user stations.")
                
            } catch {
                // Removed redundant DispatchQueue.main.async block, relying on @MainActor
                self.isLoading = false
                self.errorMessage = "Error loading your stations: \(error.localizedDescription)"
            }
        }
    }

    // Load business's stations (for business dashboard)
    func loadUserBusinessStations(userId: String) {
        isLoading = true; errorMessage = nil
        userStations = []
        print("DEBUG: Loading BUSINESS stations for user: \(userId)")
        
        // Use a Task for async Firestore operation
        Task {
            do {
                let snapshot = try await db.collection("refillStations")
                    .whereField("addedBy", isEqualTo: userId)
                    .whereField("listingType", isEqualTo: ListingType.business.rawValue)
                    .getDocuments()
                
                // Use the FirebaseManager's new parsing helper
                let fetchedStations = snapshot.documents.compactMap { document in
                    FirebaseManager.shared.stationFromFirestoreDocument(document: document, id: document.documentID)
                }

                // Removed redundant DispatchQueue.main.async block, relying on @MainActor
                self.isLoading = false
                self.userStations = fetchedStations.sorted { $0.dateAdded > $1.dateAdded }
                print("DEBUG: Parsed \(self.userStations.count) business locations.")
                
            } catch {
                // Removed redundant DispatchQueue.main.async block, relying on @MainActor
                self.isLoading = false
                self.errorMessage = "Error loading your business locations: \(error.localizedDescription)"
            }
        }
    }

    // Get Photo - Implementation updated to use async/await internally
    func getPhoto(for photoID: String, completion: @escaping (UIImage?) -> Void) {
        print("DEBUG: ViewModel getPhoto called for ID/Path: \(photoID)")
        if let cachedImage = photoCache[photoID] {
            print("DEBUG: Returning cached image for \(photoID)")
            completion(cachedImage); return
        }
        
        // Use a Task to call the async FirebaseManager function
        Task {
            // Call the new async loadStationPhoto function
            let image = await FirebaseManager.shared.loadStationPhoto(path: photoID)
            
            // Completion handler called inside the MainActor context
            if let img = image {
                print("DEBUG: Downloaded image for \(photoID), adding to cache")
                self.photoCache[photoID] = img
            } else {
                print("⚠️ DEBUG: Failed to download image for \(photoID)")
            }
            completion(image)
        }
    }
}
