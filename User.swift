import Foundation
import FirebaseFirestore
import SwiftUI

// Define the consolidated User model for authentication and profile data.
struct User: Identifiable {
    let id: String
    let email: String
    var username: String
    let dateJoined: Date
    var profileImageUrl: String?
    var role: String? // e.g., "user" or "business"
    var isVerified: Bool
    
    // Stats/Contributions (Stored in Firestore)
    var stationsAdded: Int
    var reviewsWritten: Int // Total reviews written
    var personalRefillsLogged: Int // Total refills logged

    // Other stored user data
    var favoriteStations: [String]
    
    // Settings (Managed by @AppStorage/Firestore)
    var defaultSearchRadius: Double
    var useDarkMode: Bool
    var notificationsEnabled: Bool
    
    // MARK: - Calculated Properties
    
    // Calculates total contributions (Stations + Reviews + Refills logged)
    var totalContributions: Int {
        return stationsAdded + reviewsWritten + personalRefillsLogged
    }

    // Calculates estimated CO2 saved based on logged refills.
    // Based on the existing logic: each refill saves ~0.082 kg of CO2.
    var co2SavedKg: Int {
        return Int(Double(personalRefillsLogged) * 0.082)
    }
    
    // MARK: - Factory Method
    
    // Create a User object from Firestore document data
    static func fromFirestore(documentId: String, data: [String: Any]) -> User? {
        guard
            let email = data["email"] as? String,
            let username = data["username"] as? String,
            let dateJoinedTimestamp = data["dateJoined"] as? Timestamp
        else {
            return nil
        }
        
        let dateJoined = dateJoinedTimestamp.dateValue()
        
        return User(
            id: documentId,
            email: email,
            username: username,
            dateJoined: dateJoined,
            profileImageUrl: data["profileImageUrl"] as? String,
            role: data["role"] as? String,
            isVerified: data["isVerified"] as? Bool ?? false,
            stationsAdded: data["stationsAdded"] as? Int ?? 0,
            reviewsWritten: data["reviewsWritten"] as? Int ?? 0,
            personalRefillsLogged: data["personalRefillsLogged"] as? Int ?? 0,
            favoriteStations: data["favoriteStations"] as? [String] ?? [],
            defaultSearchRadius: data["defaultSearchRadius"] as? Double ?? 1.0,
            useDarkMode: data["useDarkMode"] as? Bool ?? false,
            notificationsEnabled: data["notificationsEnabled"] as? Bool ?? true
        )
    }
}
