import Foundation
import CoreLocation
import FirebaseFirestore
import SwiftUI // Needed for Published

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
         let station1 = RefillStation(id: UUID(), coordinate: CLLocationCoordinate2D(latitude: center.latitude + 0.001, longitude: center.longitude + 0.001), name: "City Park Fountain (Sample)", description: "Public water fountain", locationType: .waterFountain, cost: .free, limitations: "24/7", photoIDs: ["sample1"], dateAdded: Date(), addedByUserID: "user1", averageRating: 4.5, ratingsCount: 12, isCarAccessible: true, isDraft: false)
         let station2 = RefillStation(id: UUID(), coordinate: CLLocationCoordinate2D(latitude: center.latitude - 0.002, longitude: center.longitude + 0.002), name: "Coffee Bean Cafe (Sample)", description: "Refill for customers", locationType: .cafe, cost: .purchaseRequired, limitations: "7am-7pm", photoIDs: ["sample2"], dateAdded: Date(), addedByUserID: "user2", averageRating: 3.8, ratingsCount: 5, isCarAccessible: false, isDraft: false)
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
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.stations = fetchedStations
                    self.errorMessage = fetchedStations.isEmpty ? "No stations found in your area yet. Be the first to add one!" : nil
                    print("DEBUG: Loaded \(self.stations.count) stations from Firebase")
                }
            } catch {
                DispatchQueue.main.async {
                     print("🔴 DEBUG: Error loading stations from Firebase: \(error.localizedDescription)")
                     self.isLoading = false
                     self.errorMessage = "Failed to load stations: \(error.localizedDescription)"
                     self.stations = []
                 }
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
                 DispatchQueue.main.async {
                     self.isLoading = false
                     if !self.stations.contains(where: { $0.id == station.id }) {
                          self.stations.append(station)
                     }
                     if !station.addedByUserID.isEmpty && !self.userStations.contains(where: { $0.id == station.id }) {
                         self.userStations.append(station)
                     }
                     completion(true, nil)
                 }
             } catch {
                 DispatchQueue.main.async {
                     print("🔴 DEBUG: Firebase save failed in ViewModel: \(error.localizedDescription)")
                     self.isLoading = false
                     let specificError = error as NSError
                     completion(false, "Failed to save station: \(specificError.localizedDescription)")
                 }
             }
         }
     }

    // Load user's stations (for regular users)
    func loadUserStations(userId: String) {
        isLoading = true; errorMessage = nil
        userStations = []
        print("DEBUG: Loading USER-ADDED stations for user: \(userId)")
        db.collection("refillStations")
            .whereField("addedBy", isEqualTo: userId)
            .whereField("listingType", isEqualTo: "user")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error = error {
                        self.errorMessage = "Error loading your stations: \(error.localizedDescription)"
                        return
                    }
                    guard let documents = snapshot?.documents else { return }
                    self.userStations = documents.compactMap { RefillStation.fromFirestoreDocument($0) }.sorted { $0.dateAdded > $1.dateAdded }
                }
            }
    }

    // Load business's stations (for business dashboard)
    func loadUserBusinessStations(userId: String) {
        isLoading = true; errorMessage = nil
        userStations = []
        print("DEBUG: Loading BUSINESS stations for user: \(userId)")
        db.collection("refillStations")
            .whereField("addedBy", isEqualTo: userId)
            .whereField("listingType", isEqualTo: "business")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error = error {
                        self.errorMessage = "Error loading your business locations: \(error.localizedDescription)"
                        return
                    }
                    guard let documents = snapshot?.documents else { return }
                    self.userStations = documents.compactMap { RefillStation.fromFirestoreDocument($0) }.sorted { $0.dateAdded > $1.dateAdded }
                    print("DEBUG: Parsed \(self.userStations.count) business locations.")
                }
            }
    }

    // Get Photo
    func getPhoto(for photoID: String, completion: @escaping (UIImage?) -> Void) {
        print("DEBUG: ViewModel getPhoto called for ID/Path: \(photoID)")
        if let cachedImage = photoCache[photoID] {
            print("DEBUG: Returning cached image for \(photoID)")
            completion(cachedImage); return
        }
        FirebaseManager.shared.loadStationPhoto(path: photoID) { [weak self] image in
            if let img = image {
                print("DEBUG: Downloaded image for \(photoID), adding to cache")
                self?.photoCache[photoID] = img
            } else {
                print("⚠️ DEBUG: Failed to download image for \(photoID)")
            }
            completion(image)
        }
    }
}
