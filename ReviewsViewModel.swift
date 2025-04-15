import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Combine

class ReviewsManager: ObservableObject {
    private let db = Firestore.firestore()
    
    // Published properties for the UI to observe
    @Published var stationReviews: [StationReview] = []
    @Published var averageRating: Double = 0
    @Published var ratingsCount: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userReview: StationReview?
    
    private var listeners: [ListenerRegistration] = []
    
    deinit {
        // Clean up listeners when this object is deallocated
        removeListeners()
    }
    
    // MARK: - Public Methods
    
    // Fetch reviews for a specific station
    func fetchReviews(for stationId: String, currentUserId: String?) {
        isLoading = true
        errorMessage = nil
        
        // Remove any existing listeners
        removeListeners()
        
        // Create a listener for real-time updates
        let listener = db.collection("reviews")
            .whereField("stationId", isEqualTo: stationId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = "Error fetching reviews: \(error.localizedDescription)"
                    self.isLoading = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.stationReviews = []
                    self.isLoading = false
                    return
                }
                
                // Convert documents to reviews
                self.stationReviews = documents.compactMap { StationReview.fromFirestore(document: $0) }
                
                // Calculate average rating
                self.averageRating = self.stationReviews.averageRating()
                self.ratingsCount = self.stationReviews.count
                
                // Find current user's review if exists
                if let currentUserId = currentUserId {
                    self.userReview = self.stationReviews.first(where: { $0.userId == currentUserId })
                } else {
                    self.userReview = nil
                }
                
                self.isLoading = false
            }
        
        // Store the listener for cleanup
        listeners.append(listener)
    }
    
    // Post a new review
    func postReview(review: StationReview) async -> Bool {
        do {
            // Save to Firestore
            try await db.collection("reviews").document(review.id).setData(review.toFirestoreData())
            
            // Update station's average rating
            await updateStationRatingInfo(stationId: review.stationId)
            
            // Update user's review count
            await updateUserReviewCount(userId: review.userId)
            
            return true
        } catch {
            errorMessage = "Error posting review: \(error.localizedDescription)"
            return false
        }
    }
    
    // Update an existing review
    func updateReview(review: StationReview) async -> Bool {
        // Mark as edited
        var updatedReview = review
        updatedReview.isEdited = true
        updatedReview.dateUpdated = Date()
        
        do {
            // Update in Firestore
            try await db.collection("reviews").document(review.id).updateData(updatedReview.toFirestoreData())
            
            // Update station's average rating
            await updateStationRatingInfo(stationId: review.stationId)
            
            return true
        } catch {
            errorMessage = "Error updating review: \(error.localizedDescription)"
            return false
        }
    }
    
    // Delete a review
    func deleteReview(review: StationReview) async -> Bool {
        do {
            // Remove from Firestore
            try await db.collection("reviews").document(review.id).delete()
            
            // Update station's average rating
            await updateStationRatingInfo(stationId: review.stationId)
            
            // Update user's review count
            await updateUserReviewCount(userId: review.userId, decrement: true)
            
            return true
        } catch {
            errorMessage = "Error deleting review: \(error.localizedDescription)"
            return false
        }
    }
    
    // Mark a review as helpful
    func markReviewAsHelpful(review: StationReview, userId: String) async -> Bool {
        // Can't mark your own review as helpful
        if review.userId == userId {
            errorMessage = "You cannot mark your own review as helpful"
            return false
        }
        
        // Check if user already marked this review as helpful
        if review.userHasMarkedHelpful.contains(userId) {
            errorMessage = "You've already marked this review as helpful"
            return false
        }
        
        var updatedReview = review
        updatedReview.helpfulCount += 1
        updatedReview.userHasMarkedHelpful.append(userId)
        
        do {
            try await db.collection("reviews").document(review.id).updateData([
                "helpfulCount": updatedReview.helpfulCount,
                "userHasMarkedHelpful": FieldValue.arrayUnion([userId])
            ])
            return true
        } catch {
            errorMessage = "Error marking review as helpful: \(error.localizedDescription)"
            return false
        }
    }
    
    // Report a review as inappropriate
    func reportReview(review: StationReview) async -> Bool {
        do {
            try await db.collection("reviews").document(review.id).updateData([
                "reportCount": FieldValue.increment(Int64(1))
            ])
            return true
        } catch {
            errorMessage = "Error reporting review: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Private Methods
    
    // Remove all active listeners
    private func removeListeners() {
        for listener in listeners {
            listener.remove()
        }
        listeners.removeAll()
    }
    
    // Get the currently signed-in user ID
    private func getCurrentUserId() -> String? {
        return FirebaseAuth.Auth.auth().currentUser?.uid
    }
    
    // Update station's average rating information in Firestore
    private func updateStationRatingInfo(stationId: String) async {
        do {
            // Fetch all reviews for this station
            let snapshot = try await db.collection("reviews")
                .whereField("stationId", isEqualTo: stationId)
                .getDocuments()
            
            let reviews = snapshot.documents.compactMap { StationReview.fromFirestore(document: $0) }
            let averageRating = reviews.averageRating()
            let ratingsCount = reviews.count
            
            // Update the station document with the new rating info
            try await db.collection("refillStations").document(stationId).updateData([
                "averageRating": averageRating,
                "ratingsCount": ratingsCount
            ])
        } catch {
            errorMessage = "Error updating station rating: \(error.localizedDescription)"
        }
    }
    
    // Update user's review count
    private func updateUserReviewCount(userId: String, decrement: Bool = false) async {
        do {
            let value: Int64 = decrement ? -1 : 1
            try await db.collection("users").document(userId).updateData([
                "reviewsWritten": FieldValue.increment(value),
                "contributions": FieldValue.increment(value)
            ])
        } catch {
            errorMessage = "Error updating user stats: \(error.localizedDescription)"
        }
    }
    
    // Fetch user's reviews
    func fetchUserReviews(for userId: String) async -> [StationReview] {
        do {
            let snapshot = try await db.collection("reviews")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            return snapshot.documents.compactMap { StationReview.fromFirestore(document: $0) }
        } catch {
            errorMessage = "Error fetching user reviews: \(error.localizedDescription)"
            return []
        }
    }
    
    // Get a list of stations the user has reviewed
    func fetchStationsUserHasReviewed() async -> [String] {
        guard let userId = getCurrentUserId() else { return [] }
        
        do {
            let snapshot = try await db.collection("reviews")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            return snapshot.documents.compactMap { document in
                document.data()["stationId"] as? String
            }
        } catch {
            errorMessage = "Error fetching user's reviewed stations: \(error.localizedDescription)"
            return []
        }
    }
}
