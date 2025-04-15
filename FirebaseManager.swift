import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import CoreLocation
import UIKit

class FirebaseManager {
    static let shared = FirebaseManager()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private init() {}

    // MARK: - Refill Stations

    /// Saves station data to Firestore and photo paths to Storage.
    func saveRefillStation(_ station: RefillStation, photos: [UIImage], userId: String) async throws {
        print("DEBUG: FirebaseManager saveRefillStation called for station: \(station.name)")
        let stationRef = db.collection("refillStations").document()
        let stationFirestoreId = stationRef.documentID
        print("DEBUG: Created Firestore document with ID: \(stationFirestoreId)")

        var photoStoragePaths: [String] = []

        print("DEBUG: Starting upload of \(photos.count) photos")
        for (index, photo) in photos.enumerated() {
            guard let photoData = photo.jpegData(compressionQuality: 0.7) else {
                print("DEBUG: Warning - Could not compress photo \(index+1) into JPEG data.")
                continue
            }

            let photoFileName = "\(UUID().uuidString).jpg"
            let photoStoragePath = "stations/\(stationFirestoreId)/\(photoFileName)"
            let photoStorageRef = storage.reference().child(photoStoragePath)
            print("DEBUG: Preparing to upload photo \(index+1) to \(photoStorageRef.fullPath)")

            do {
                print("DEBUG: Attempting photoRef.putDataAsync for photo \(index+1)...")
                _ = try await photoStorageRef.putDataAsync(photoData)
                print("✅ DEBUG: putDataAsync appears complete for photo \(index+1).")
                print("DEBUG: Storing photo PATH: \(photoStoragePath)")
                photoStoragePaths.append(photoStoragePath) // Store the path

            } catch {
                print("🔴🔴🔴 ERROR during photo \(index+1) upload: \(error.localizedDescription)")
                print("🔴🔴🔴 Full Error Details: \(error)")
                throw error
            }
        }

        print("DEBUG: All photo uploads successful (\(photoStoragePaths.count)/\(photos.count)). Preparing Firestore data.")
        let stationData: [String: Any] = [
            "name": station.name, "location": GeoPoint(latitude: station.coordinate.latitude, longitude: station.coordinate.longitude),
            "type": station.locationType.rawValue, "cost": station.cost.rawValue,
            "description": station.description, "limitations": station.limitations,
            "photoIDs": photoStoragePaths, // Saving paths
            "addedBy": userId, "dateAdded": Timestamp(date: Date()), "verified": false,
            "averageRating": 0.0, "ratingsCount": 0
        ]
        print("DEBUG: Saving station data to Firestore doc ID: \(stationFirestoreId)")
        do {
            try await stationRef.setData(stationData)
            print("DEBUG: Station data saved successfully to Firestore.")
        } catch { print("🔴🔴🔴 ERROR saving station data to Firestore: \(error.localizedDescription)"); throw error }

        if !userId.isEmpty {
            print("DEBUG: Updating user contribution count for user: \(userId)")
             do {
                 let userDocRef = db.collection("users").document(userId)
                 try await userDocRef.updateData(["stationsAdded": FieldValue.increment(Int64(1)), "contributions": FieldValue.increment(Int64(1))])
                 print("DEBUG: User contribution count updated.")
             } catch { print("🔴🔴🔴 ERROR updating user stats: \(error.localizedDescription)") }
        } else { print("DEBUG: No user ID provided, skipping contribution update") }
        print("DEBUG: saveRefillStation completed successfully")
    }

    /// Fetches nearby stations (Reads photoIDs which should contain paths)
    func fetchNearbyStations(center: CLLocationCoordinate2D, radiusInMiles: Double) async throws -> [RefillStation] {
        // ... (Implementation remains the same) ...
        print("DEBUG: FirebaseManager fetchNearbyStations called.")
        let radiusInDegrees = radiusInMiles / 69.0; let centerLat = center.latitude; let centerLon = center.longitude
        let lowerLat = centerLat - radiusInDegrees; let upperLat = centerLat + radiusInDegrees
        let lowerLon = centerLon - radiusInDegrees; let upperLon = centerLon + radiusInDegrees
        let lowerBound = GeoPoint(latitude: lowerLat, longitude: lowerLon); let upperBound = GeoPoint(latitude: upperLat, longitude: upperLon)
        print("DEBUG: Querying Firestore with Lat [\(lowerLat) - \(upperLat)], Lon [\(lowerLon) - \(upperLon)]")
        print("DEBUG: === TRYING TO EXECUTE FIRESTORE GEO QUERY ===")
        let querySnapshot: QuerySnapshot
        do {
            querySnapshot = try await db.collection("refillStations").whereField("location", isGreaterThan: lowerBound).whereField("location", isLessThan: upperBound).getDocuments()
             print("DEBUG: === FIRESTORE GEO QUERY FINISHED (Retrieved \(querySnapshot.documents.count) docs) ===")
        } catch { print("🔴🔴🔴 ERROR executing Firestore geo query: \(error.localizedDescription)"); throw error }
        let radiusInMeters = radiusInMiles * 1609.34; let centerLocation = CLLocation(latitude: centerLat, longitude: centerLon)
        let stations = querySnapshot.documents.compactMap { document -> RefillStation? in
            let data = document.data()
            guard let location = data["location"] as? GeoPoint, let name = data["name"] as? String, let typeString = data["type"] as? String, let costString = data["cost"] as? String, let description = data["description"] as? String, let limitations = data["limitations"] as? String, let photoIDs = data["photoIDs"] as? [String], let timestamp = data["dateAdded"] as? Timestamp, let addedBy = data["addedBy"] as? String else { return nil }
            let stationCoordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude); let stationLocation = CLLocation(latitude: stationCoordinate.latitude, longitude: stationCoordinate.longitude)
            let distanceInMeters = stationLocation.distance(from: centerLocation); guard distanceInMeters <= radiusInMeters else { return nil }
            let locationType = RefillStation.LocationType(rawValue: typeString) ?? .other; let costType = RefillStation.RefillCost(rawValue: costString) ?? .free
            let stationFirestoreId = document.documentID
            return RefillStation(id: UUID(uuidString: stationFirestoreId) ?? UUID(), coordinate: stationCoordinate, name: name, description: description, locationType: locationType, cost: costType, limitations: limitations, photos: [], photoIDs: photoIDs, dateAdded: timestamp.dateValue(), addedByUserID: addedBy, averageRating: data["averageRating"] as? Double, ratingsCount: data["ratingsCount"] as? Int ?? 0)
        }
        print("DEBUG: Returning \(stations.count) stations after precise radius filtering.")
        return stations
    }

    // MARK: - Photo Management

    /// Downloads a photo from Firebase Storage using its PATH.
    func downloadPhoto(photoPath: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
         print("Attempting to download photo with PATH: \(photoPath)")
         let storageRef = storage.reference().child(photoPath)
         storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
             if let error = error { print("Download error for PATH \(photoPath): \(error.localizedDescription)"); completion(.failure(error)); return }
             guard let imageData = data, let image = UIImage(data: imageData) else { let dataError = NSError(domain: "FirebaseManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image data for PATH: \(photoPath)"]); completion(.failure(dataError)); return }
             completion(.success(image))
         }
     }

    /// Unified method called by ViewModels to load station photos. Expects a PATH string.
    func loadStationPhoto(path: String, completion: @escaping (UIImage?) -> Void) {
        print("DEBUG: loadStationPhoto called with PATH: \(path)")
        downloadPhoto(photoPath: path) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let image): completion(image)
                case .failure(let error): print("Failed to load photo for PATH \(path): \(error.localizedDescription)"); completion(nil)
                }
            }
        }
    }

    // MARK: - User Profile Photos

     /// Uploads a profile photo to a specific user path and updates the user's document with the path.
     func uploadProfilePhoto(userId: String, image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
         print("Starting profile photo upload for user: \(userId)")
         let profilePhotoPath = "users/\(userId)/profile.jpg"
         let storageRef = storage.reference().child(profilePhotoPath)

         guard let imageData = image.jpegData(compressionQuality: 0.8) else {
             let error = NSError(domain: "FirebaseManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to convert profile image to data"])
             completion(.failure(error))
             return
         }
         let metadata = StorageMetadata()
         metadata.contentType = "image/jpeg"
         print("Uploading profile photo to: \(profilePhotoPath)")

         storageRef.putData(imageData, metadata: metadata) { _, putError in
             if let putError = putError {
                 print("Profile photo upload error: \(putError.localizedDescription)")
                 completion(.failure(putError))
                 return
             }
             print("Successfully uploaded profile photo data.")
             // Instead of getting the download URL, we'll return the path
             completion(.success(profilePhotoPath))
         }
     }

     /// Downloads a user's profile photo using the URL or path stored in their profile.
     func downloadProfilePhoto(profileImageUrlOrPath: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        print("DEBUG: downloadProfilePhoto called with: \(profileImageUrlOrPath)")
         // Always treat as a path
         print("DEBUG: Attempting to download profile photo from path: \(profileImageUrlOrPath)")
         let storageRef = storage.reference().child(profileImageUrlOrPath)
         storageRef.getData(maxSize: 5 * 1024 * 1024) { data, error in
             if let error = error {
                 print("Download error from path '\(profileImageUrlOrPath)': \(error.localizedDescription)")
                 completion(.failure(error))
                 return
             }
             guard let imageData = data, let image = UIImage(data: imageData) else {
                  let dataError = NSError(domain: "FirebaseManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to convert profile photo data from path."])
                  completion(.failure(dataError))
                 return
             }
             print("Successfully downloaded profile photo from path")
             completion(.success(image))
         }
     }

    // --- Other Functions ---
    func updateUserProfile(userId: String, updates: [String: Any], completion: @escaping (Result<Void, Error>) -> Void) {
        // ... (Remains the same) ...
        print("Updating user profile for userId: \(userId)...")
        db.collection("users").document(userId).updateData(updates) { error in
             if let error = error { completion(.failure(error)) } else { completion(.success(())) } }
    }

} // End class FirebaseManager
