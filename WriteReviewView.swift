import SwiftUI

struct WriteReviewView: View {
    let stationId: String
    let reviewToEdit: StationReview?
    let onSave: (StationReview) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject var toastManager: ToastManager // NEW: Inject Toast Manager
    
    @State private var rating: Int
    @State private var comment: String
    @State private var isSubmitting = false
    // REMOVED: @State private var errorMessage: String?
    // REMOVED: @State private var showingError = false

    // Initialize with either a review to edit or default values
    init(stationId: String, reviewToEdit: StationReview?, onSave: @escaping (StationReview) -> Void) {
        self.stationId = stationId
        self.reviewToEdit = reviewToEdit
        self.onSave = onSave
        
        // Set initial values based on whether we're editing an existing review
        _rating = State(initialValue: reviewToEdit?.rating ?? 0)
        _comment = State(initialValue: reviewToEdit?.comment ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Your Rating")) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Interactive star rating selector
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                                    .font(.title)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            rating = star
                                        }
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                        
                        // Rating description
                        Text(ratingDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Your Review")) {
                    // Review text area
                    ZStack(alignment: .topLeading) {
                        if comment.isEmpty {
                            Text("Share your experience with this refill station...")
                                .foregroundColor(.gray.opacity(0.8))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        
                        TextEditor(text: $comment)
                            .frame(minHeight: 150)
                            .opacity(comment.isEmpty ? 0.25 : 1)
                    }
                    
                    // Character count
                    Text("\(comment.count)/1000 characters")
                        .font(.caption)
                        .foregroundColor(comment.count > 1000 ? .red : .secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                
                // Review guidelines
                Section(header: Text("Guidelines")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Be honest and specific", systemImage: "checkmark.circle")
                            .font(.caption)
                        
                        Label("Focus on the water quality and accessibility", systemImage: "checkmark.circle")
                            .font(.caption)
                        
                        Label("Keep it respectful and helpful", systemImage: "checkmark.circle")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle(reviewToEdit == nil ? "Write a Review" : "Edit Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(reviewToEdit == nil ? "Post" : "Update") {
                        submitReview()
                    }
                    .disabled(!isValid || isSubmitting)
                    .opacity(isValid ? 1.0 : 0.5)
                }
            }
            .disabled(isSubmitting)
            .overlay(
                Group {
                    if isSubmitting {
                        VStack {
                            ProgressView("Submitting...")
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                        .ignoresSafeArea()
                    }
                }
            )
            // REMOVED: .alert modifier
        }
    }
    
    // MARK: - Computed Properties
    
    // Check if the review is valid (has a rating and comment within limits)
    private var isValid: Bool {
        rating > 0 && !comment.isEmpty && comment.count <= 1000
    }
    
    // Description based on the selected rating
    private var ratingDescription: String {
        switch rating {
        case 0: return "Tap the stars to rate"
        case 1: return "Poor - Would not recommend"
        case 2: return "Fair - Has significant issues"
        case 3: return "Average - Ok but has some issues"
        case 4: return "Good - Recommended with minor issues"
        case 5: return "Excellent - Highly recommended"
        default: return ""
        }
    }
    
    // MARK: - Actions
    
    // Submit the review (create new or update existing)
    private func submitReview() {
        guard let user = authManager.currentUser, isValid else {
            // UPDATED: Use ToastManager
            toastManager.show(message: "Please complete your review before submitting.", isError: true)
            return
        }
        
        isSubmitting = true
        
        if let existingReview = reviewToEdit {
            // Update existing review
            var updatedReview = existingReview
            updatedReview.rating = rating
            updatedReview.comment = comment
            updatedReview.isEdited = true
            updatedReview.dateUpdated = Date()
            
            onSave(updatedReview)
        } else {
            // Create new review
            let newReview = StationReview.newReview(
                stationId: stationId,
                userId: user.id,
                username: user.username,
                rating: rating,
                comment: comment
            )
            
            onSave(newReview)
        }
    }
}

struct WriteReviewView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthManager.shared
        
        return Group {
            // Preview for writing a new review
            WriteReviewView(
                stationId: "previewStationId",
                reviewToEdit: nil,
                onSave: { _ in }
            )
            .environmentObject(authManager)
            .environmentObject(ToastManager.shared) // Inject ToastManager

            // Preview for editing an existing review
            WriteReviewView(
                stationId: "previewStationId",
                reviewToEdit: StationReview(
                    id: "reviewId",
                    stationId: "previewStationId",
                    userId: "userId",
                    username: "Test User",
                    rating: 4,
                    comment: "This is an existing review that is being edited.",
                    datePosted: Date().addingTimeInterval(-86400),
                    dateUpdated: nil,
                    isEdited: false,
                    userPhotoURL: nil,
                    helpfulCount: 2,
                    reportCount: 0,
                    userHasMarkedHelpful: []
                ),
                onSave: { _ in }
            )
            .environmentObject(authManager)
            .environmentObject(ToastManager.shared) // Inject ToastManager
        }
    }
}
