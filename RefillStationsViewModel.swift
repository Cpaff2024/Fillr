import Foundation
import CoreLocation
import FirebaseFirestore
import SwiftUI

// This class manages all the water refill stations data
class RefillStationsViewModel: ObservableObject {
    // All the refill stations we know about
    @Published var stations: [RefillStation] = []

    // Stations that are user favorites
    @Published var favoriteStations: [RefillStation] = [] // Assuming favorites are loaded elsewhere or identified within 'stations'

    // Stations that the user created
    @Published var userStations: [RefillStation] = []

    // Loading state
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Selected filters
    @Published var selectedLocationTypes: Set<RefillStation.LocationType> = Set(RefillStation.LocationType.allCases)
    @Published var selectedCostTypes: Set<RefillStation.RefillCost> = Set(RefillStation.RefillCost.allCases)
    @Published var showOnlyFavorites = false // This needs to be linked to AuthManager or User Profile
    @Published var minimumRating: Int = 0 // This should probably be in FilterView state

    // Firebase reference
    private lazy var db = Firestore.firestore()

    // Photo cache for quick loading
    private var photoCache: [String: UIImage] = [:]

    // Computed property for filtered stations
    var filteredStations: [RefillStation] {
        // --- DIAGNOSTIC PRINT ---
         // print("--- Filtering Stations ---") // Keep commented out unless debugging filters
         // print("Total stations before filtering: \(stations.count)")
         // print("Active Filters - Types: \(selectedLocationTypes.map { $0.rawValue })")
         // print("Active Filters - Costs: \(selectedCostTypes.map { $0.rawValue })")
         // print("Active Filters - Min Rating: \(minimumRating)")

        let filtered = stations.filter { station in
            let matchesType = selectedLocationTypes.contains(station.locationType)
            let matchesCost = selectedCostTypes.contains(station.cost)

            let matchesRating: Bool
            if minimumRating > 0 {
                if let rating = station.averageRating { matchesRating = rating >= Double(minimumRating) }
                else { matchesRating = false }
            } else {
                matchesRating = true
            }

            // Favorites filter placeholder
            let matchesFavorites = true

            let doesMatch = matchesType && matchesCost && matchesRating && matchesFavorites

            // --- DIAGNOSTIC PRINT ---
            // if !doesMatch && stations.contains(where: { $0.id == station.id }) {
            //     print("Station '\(station.name)' (\(station.id)) was FILTERED OUT.")
            //     // ... reasons ...
            // }

            return doesMatch
        }

        // print("Stations after filtering: \(filtered.count)")
        // print("--- End Filtering ---")
        return filtered
    }

    // Load sample stations for preview mode
    func loadSampleStations() {
        // ... (Sample data generation remains the same) ...
        print("DEBUG: Loading sample stations")
        let center = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let station1 = RefillStation( id: UUID(), coordinate: CLLocationCoordinate2D(latitude: center.latitude + 0.001, longitude: center.longitude + 0.001), name: "City Park Fountain", description: "Public water fountain in the main square", locationType: .waterFountain, cost: .free, limitations: "Available 24/7", photos: [], photoIDs: ["sample1"], dateAdded: Date(), addedByUserID: "user1", averageRating: 4.5, ratingsCount: 12 )
        let station2 = RefillStation( id: UUID(), coordinate: CLLocationCoordinate2D(latitude: center.latitude - 0.002, longitude: center.longitude + 0.002), name: "Coffee Bean Cafe", description: "They're happy to refill water bottles for customers", locationType: .cafe, cost: .purchaseRequired, limitations: "Open 7am-7pm", photos: [], photoIDs: ["sample2"], dateAdded: Date(), addedByUserID: "user2", averageRating: 3.8, ratingsCount: 5 )
        let station3 = RefillStation( id: UUID(), coordinate: CLLocationCoordinate2D(latitude: center.latitude + 0.003, longitude: center.longitude - 0.001), name: "Central Train Station", description: "Water fountain near platform 1", locationType: .publicSpace, cost: .free, limitations: "Station hours only", photos: [], photoIDs: ["sample3"], dateAdded: Date(), addedByUserID: "user1" )
        stations = [station1, station2, station3]
        userStations = stations.filter { $0.addedByUserID == "user1" }
        print("DEBUG: Loaded \(stations.count) sample stations")
    }

    // Load stations near a specific location
    func loadNearbyStations(center: CLLocationCoordinate2D, radiusInMiles: Double) {
        print("DEBUG: ViewModel loadNearbyStations called with center: \(center.latitude), \(center.longitude), radius: \(radiusInMiles)")

        let inPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        if inPreview {
            print("DEBUG: In preview mode - loading sample stations")
            loadSampleStations()
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                print("DEBUG: Fetching stations from FirebaseManager")
                let fetchedStations = try await FirebaseManager.shared.fetchNearbyStations(center: center, radiusInMiles: radiusInMiles)

                DispatchQueue.main.async {
                    self.isLoading = false
                    print("DEBUG: Loaded \(fetchedStations.count) stations from Firebase")
                    self.stations = fetchedStations
                    self.errorMessage = fetchedStations.isEmpty ? "No stations found in your area yet. Be the first to add one!" : nil
                    print("DEBUG: After loading, stations count: \(self.stations.count)")
                }
            } catch {
                DispatchQueue.main.async {
                    print("DEBUG: Error loading from FirebaseManager: \(error.localizedDescription)")
                    self.isLoading = false
                    self.errorMessage = "Failed to load stations: \(error.localizedDescription)"
                    self.stations = []
                }
            }
        }
    }

    // Add a new station
     func addStation(_ station: RefillStation, photos: [UIImage], completion: @escaping (Bool, String?) -> Void) {
         isLoading = true
         errorMessage = nil

         print("DEBUG: ViewModel addStation called for: \(station.name)")

         let inPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
         if inPreview {
             DispatchQueue.main.async {
                 self.stations.append(station)
                 if !station.addedByUserID.isEmpty { self.userStations.append(station) }
                 self.isLoading = false
                 print("DEBUG: Station added to local arrays in preview")
                 completion(true, nil)
             }
             return
         }

         Task {
             do {
                 print("DEBUG: Calling FirebaseManager saveRefillStation for \(station.name)")
                 // Call the save function (which now uses paths internally)
                 try await FirebaseManager.shared.saveRefillStation(station, photos: photos, userId: station.addedByUserID)

                 DispatchQueue.main.async {
                     print("DEBUG: Firebase save successful, updating local 'stations' array.")
                     self.isLoading = false
                     // Add station locally ONLY after successful save
                     self.stations.append(station)
                     if !station.addedByUserID.isEmpty {
                         self.userStations.append(station)
                         print("DEBUG: Added to userStations array")
                     }
                     print("DEBUG: Local 'stations' array updated. Count: \(self.stations.count)")
                     completion(true, nil) // Signal success
                 }
             } catch {
                 DispatchQueue.main.async {
                     print("DEBUG: Firebase save failed in ViewModel: \(error.localizedDescription)")
                     self.isLoading = false
                     // Use the specific error from FirebaseManager if possible
                     let specificError = error as NSError
                     self.errorMessage = "Failed to save station: \(specificError.localizedDescription)"
                     completion(false, self.errorMessage) // Signal failure
                 }
             }
         }
     } // End addStation

    // Load user's stations
    func loadUserStations(userId: String) {
        // ... (Implementation remains the same) ...
        let inPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        if inPreview { loadSampleStations(); return }
        isLoading = true; errorMessage = nil
        print("DEBUG: Loading stations for user: \(userId)")
        db.collection("refillStations").whereField("addedBy", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error = error {
                         print("DEBUG: Error loading user stations: \(error.localizedDescription)")
                        self.errorMessage = "Error loading your stations: \(error.localizedDescription)"
                        self.userStations = []; return
                    }
                    guard let documents = snapshot?.documents else {
                         print("DEBUG: No documents found for user stations."); self.userStations = []; return
                    }
                    print("DEBUG: Found \(documents.count) documents for user stations.")
                    self.userStations = documents.compactMap { self.createStationFromDocument($0) }
                    print("DEBUG: Parsed \(self.userStations.count) user stations.")
                }
            }
    } // End loadUserStations

    // Helper method to create a RefillStation from a Firestore document
    private func createStationFromDocument(_ document: QueryDocumentSnapshot) -> RefillStation? {
        // ... (Implementation remains the same - parses paths from photoIDs) ...
        let data = document.data()
        guard let location = data["location"] as? GeoPoint, let name = data["name"] as? String, let typeString = data["type"] as? String, let costString = data["cost"] as? String, let description = data["description"] as? String, let limitations = data["limitations"] as? String, let photoIDs = data["photoIDs"] as? [String], let timestamp = data["dateAdded"] as? Timestamp, let addedBy = data["addedBy"] as? String else {
             // print("DEBUG: Failed to parse station document \(document.documentID). Missing required fields.")
             // print("DEBUG: Data dump: \(data)")
            return nil
        }
        let locationType = RefillStation.LocationType(rawValue: typeString) ?? .other
        let costType = RefillStation.RefillCost(rawValue: costString) ?? .free
        let stationId = UUID(uuidString: document.documentID) ?? UUID()
        return RefillStation(id: stationId, coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude), name: name, description: description, locationType: locationType, cost: costType, limitations: limitations, photos: [], photoIDs: photoIDs, dateAdded: timestamp.dateValue(), addedByUserID: addedBy, averageRating: data["averageRating"] as? Double, ratingsCount: data["ratingsCount"] as? Int ?? 0)
    } // End createStationFromDocument

    // Get a photo for a station (using Photo ID which is now a PATH)
    func getPhoto(for photoID: String, completion: @escaping (UIImage?) -> Void) {
        print("DEBUG: ViewModel getPhoto called for ID/Path: \(photoID)")

        // Check cache first
        if let cachedImage = photoCache[photoID] {
            print("DEBUG: Returning cached image for \(photoID)")
            completion(cachedImage)
            return
        }

        // If not in cache, load from Firebase using the PATH
        // *** THIS IS THE CORRECTED LINE ***
        FirebaseManager.shared.loadStationPhoto(path: photoID) { [weak self] image in // Use path: label
        // *** END CORRECTION ***
            if let image = image {
                // Add to cache for next time
                print("DEBUG: Downloaded image for \(photoID), adding to cache")
                // Use weak self to avoid potential retain cycles if needed, although less likely here
                self?.photoCache[photoID] = image
            } else {
                print("DEBUG: Failed to download image for \(photoID)")
            }
            // Completion is handled on main thread inside loadStationPhoto now
            completion(image)
        }
    } // End getPhoto
} // End class
