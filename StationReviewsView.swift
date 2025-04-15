import SwiftUI
import UIKit

struct StationReviewsView: View {
    let stationId: String
    @StateObject private var reviewsManager = ReviewsManager()
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var showingSortMenu = false
    @State private var sortOption: SortOption = .recent
    @State private var showingWriteReview = false
    
    enum SortOption {
        case recent, helpful
        
        var label: String {
            switch self {
            case .recent: return "Most Recent"
            case .helpful: return "Most Helpful"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Rating summary section
            RatingSummaryView(
                averageRating: reviewsManager.averageRating,
                ratingsCount: reviewsManager.ratingsCount
            )
            .padding()
            .background(Color.blue.opacity(0.05))
            
            // Sort controls
            HStack {
                Button(action: { showingSortMenu = true }) {
                    HStack {
                        Text("Sort by: \(sortOption.label)")
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Spacer()
                
                if reviewsManager.userReview == nil {
                    Button(action: { showingWriteReview = true }) {
                        Label("Write Review", systemImage: "square.and.pencil")
                            .font(.subheadline)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // Reviews list
            if reviewsManager.isLoading {
                ProgressView()
                    .padding()
            } else if reviewsManager.stationReviews.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                        .padding()
                    
                    Text("No reviews yet")
                        .font(.headline)
                    
                    Text("Be the first to share your experience")
                        .foregroundColor(.secondary)
                    
                    Button(action: { showingWriteReview = true }) {
                        Text("Write a Review")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.top)
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sortedReviews) { review in
                            ReviewRow(
                                review: review,
                                currentUserId: authManager.currentUser?.id,
                                onEdit: {
                                    editReview(review)
                                },
                                onDelete: {
                                    deleteReview(review)
                                },
                                onMarkHelpful: {
                                    markHelpful(review)
                                },
                                onReport: {
                                    reportReview(review)
                                }
                            )
                            
                            if review.id != sortedReviews.last?.id {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Reviews")
        .confirmationDialog("Sort reviews by", isPresented: $showingSortMenu, titleVisibility: .visible) {
            Button("Most Recent") { sortOption = .recent }
            Button("Most Helpful") { sortOption = .helpful }
        }
        .sheet(isPresented: $showingWriteReview) {
            WriteReviewView(
                stationId: stationId,
                reviewToEdit: reviewsManager.userReview,
                onSave: { review in
                    Task {
                        if reviewsManager.userReview == nil {
                            let success = await reviewsManager.postReview(review: review)
                            if success {
                                showingWriteReview = false
                            }
                        } else {
                            let success = await reviewsManager.updateReview(review: review)
                            if success {
                                showingWriteReview = false
                            }
                        }
                    }
                }
            )
            .environmentObject(authManager)
        }
        .onAppear {
            reviewsManager.fetchReviews(for: stationId, currentUserId: authManager.currentUser?.id)
        }
        .alert(isPresented: Binding(
            get: { reviewsManager.errorMessage != nil },
            set: { if !$0 { reviewsManager.errorMessage = nil } }
        )) {
            Alert(
                title: Text("Error"),
                message: Text(reviewsManager.errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Computed property for sorted reviews
    private var sortedReviews: [StationReview] {
        switch sortOption {
        case .recent:
            return reviewsManager.stationReviews.sorted(by: {
                let date1 = $0.dateUpdated ?? $0.datePosted
                let date2 = $1.dateUpdated ?? $1.datePosted
                return date1 > date2
            })
        case .helpful:
            return reviewsManager.stationReviews.sorted(by: {
                $0.helpfulCount > $1.helpfulCount
            })
        }
    }
    
    // MARK: - Actions
    
    private func editReview(_ review: StationReview) {
        reviewsManager.userReview = review
        showingWriteReview = true
    }
    
    private func deleteReview(_ review: StationReview) {
        Task {
            let success = await reviewsManager.deleteReview(review: review)
            if success {
                // Will be updated via the listener
            }
        }
    }
    
    private func markHelpful(_ review: StationReview) {
        guard let userId = authManager.currentUser?.id else {
            return
        }
        
        Task {
            let _ = await reviewsManager.markReviewAsHelpful(review: review, userId: userId)
        }
    }
    
    private func reportReview(_ review: StationReview) {
        Task {
            let _ = await reviewsManager.reportReview(review: review)
        }
    }
}

// MARK: - Supporting Views

struct RatingSummaryView: View {
    let averageRating: Double
    let ratingsCount: Int
    
    var body: some View {
        VStack(spacing: 10) {
            // Average rating display
            HStack(alignment: .center) {
                Text(String(format: "%.1f", averageRating))
                    .font(.system(size: 48, weight: .bold))
                
                VStack(alignment: .leading) {
                    // Star display
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName:
                                  star <= Int(averageRating.rounded()) ? "star.fill" :
                                    (star == Int(averageRating.rounded()) + 1 && averageRating.truncatingRemainder(dividingBy: 1) >= 0.5 ?
                                     "star.leadinghalf.filled" : "star")
                            )
                            .foregroundColor(.yellow)
                        }
                    }
                    
                    // Count of ratings
                    Text("\(ratingsCount) \(ratingsCount == 1 ? "review" : "reviews")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 4)
            }
        }
    }
}

struct ReviewRow: View {
    let review: StationReview
    let currentUserId: String?
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMarkHelpful: () -> Void
    let onReport: () -> Void
    
    @State private var showingActionSheet = false
    
    private var isOwnReview: Bool {
        currentUserId == review.userId
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info and stars
            HStack(alignment: .center) {
                // User avatar (placeholder)
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.username)
                        .font(.headline)
                    
                    // Star rating display
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= review.rating ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }
                }
                
                Spacer()
                
                // Date and menu
                VStack(alignment: .trailing, spacing: 4) {
                    // Date
                    Text(formattedDate(review.dateUpdated ?? review.datePosted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Menu button
                    Button(action: { showingActionSheet = true }) {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .padding(8)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Review content
            Text(review.comment)
                .font(.body)
                .padding(.vertical, 4)
            
            // Footer with helpful button
            HStack {
                if review.isEdited {
                    Text("(edited)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 4)
                }
                
                Spacer()
                
                // Helpful count and button
                if !isOwnReview {
                    Button(action: onMarkHelpful) {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.thumbsup")
                                .font(.caption)
                            
                            Text("Helpful (\(review.helpfulCount))")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(currentUserId == nil || review.userHasMarkedHelpful.contains(where: { $0 == currentUserId! }))
                } else {
                    Text("\(review.helpfulCount) \(review.helpfulCount == 1 ? "user finds" : "users find") this helpful")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .confirmationDialog(
            isOwnReview ? "Manage Your Review" : "Review Actions",
            isPresented: $showingActionSheet,
            titleVisibility: .visible
        ) {
            if isOwnReview {
                Button("Edit Review", action: onEdit)
                Button("Delete Review", role: .destructive, action: onDelete)
            } else {
                Button("Mark as Helpful", action: onMarkHelpful)
                    .disabled(currentUserId == nil || review.userHasMarkedHelpful.contains(where: { $0 == currentUserId! }))
                Button("Report Review", role: .destructive, action: onReport)
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Preview
struct StationReviewsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            StationReviewsView(stationId: "previewStationId")
                .environmentObject(AuthManager.shared)
        }
    }
}
