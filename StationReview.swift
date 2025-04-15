import Foundation
import Firebase
import FirebaseFirestore

struct StationReview: Identifiable, Equatable {
    var id: String
    var stationId: String
    var userId: String
    var username: String
    var rating: Int  // 1-5 stars
    var comment: String
    var datePosted: Date
    var dateUpdated: Date?
    var isEdited: Bool
    var userPhotoURL: String?
    var helpfulCount: Int
    var reportCount: Int
    var userHasMarkedHelpful: [String]  // Array of user IDs who marked helpful
    
    // For creating a new review
    static func newReview(stationId: String, userId: String, username: String, rating: Int, comment: String) -> StationReview {
        return StationReview(
            id: UUID().uuidString,
            stationId: stationId,
            userId: userId,
            username: username,
            rating: rating,
            comment: comment,
            datePosted: Date(),
            dateUpdated: nil,
            isEdited: false,
            userPhotoURL: nil,
            helpfulCount: 0,
            reportCount: 0,
            userHasMarkedHelpful: []
        )
    }
    
    // Convert Firestore data to Review
    static func fromFirestore(document: QueryDocumentSnapshot) -> StationReview? {
        let data = document.data()
        
        guard
            let stationId = data["stationId"] as? String,
            let userId = data["userId"] as? String,
            let username = data["username"] as? String,
            let rating = data["rating"] as? Int,
            let comment = data["comment"] as? String,
            let datePosted = (data["datePosted"] as? Timestamp)?.dateValue()
        else {
            return nil
        }
        
        return StationReview(
            id: document.documentID,
            stationId: stationId,
            userId: userId,
            username: username,
            rating: rating,
            comment: comment,
            datePosted: datePosted,
            dateUpdated: (data["dateUpdated"] as? Timestamp)?.dateValue(),
            isEdited: data["isEdited"] as? Bool ?? false,
            userPhotoURL: data["userPhotoURL"] as? String,
            helpfulCount: data["helpfulCount"] as? Int ?? 0,
            reportCount: data["reportCount"] as? Int ?? 0,
            userHasMarkedHelpful: data["userHasMarkedHelpful"] as? [String] ?? []
        )
    }
    
    // Convert Review to Firestore data
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "stationId": stationId,
            "userId": userId,
            "username": username,
            "rating": rating,
            "comment": comment,
            "datePosted": Timestamp(date: datePosted),
            "isEdited": isEdited,
            "helpfulCount": helpfulCount,
            "reportCount": reportCount,
            "userHasMarkedHelpful": userHasMarkedHelpful
        ]
        
        if let dateUpdated = dateUpdated {
            data["dateUpdated"] = Timestamp(date: dateUpdated)
        }
        
        if let userPhotoURL = userPhotoURL {
            data["userPhotoURL"] = userPhotoURL
        }
        
        return data
    }
    
    // Equatable implementation
    static func == (lhs: StationReview, rhs: StationReview) -> Bool {
        return lhs.id == rhs.id
    }
}

// Extension for computing rating information for a collection of reviews
extension Array where Element == StationReview {
    func averageRating() -> Double {
        guard !isEmpty else { return 0 }
        let sum = self.reduce(0) { $0 + $1.rating }
        return Double(sum) / Double(count)
    }
    
    func ratingsDistribution() -> [Int: Int] {
        var distribution = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        for review in self {
            distribution[review.rating, default: 0] += 1
        }
        return distribution
    }
    
    func sortedByRecent() -> [StationReview] {
        return self.sorted { $0.dateUpdated ?? $0.datePosted > $1.dateUpdated ?? $1.datePosted }
    }
    
    func sortedByHelpful() -> [StationReview] {
        return self.sorted { $0.helpfulCount > $1.helpfulCount }
    }
}
