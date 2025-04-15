import SwiftUI

struct ReviewFormView: View {
    let stationId: String
    let userId: String
    let username: String
    let existingReview: StationReview?
    let onSubmit: (Int, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int
    @State private var reviewText: String
    @State private var dateCreated: Date = Date()
    
    // Initialize with either existing review data or default values
    init(stationId: String, userId: String, username: String, existingReview: StationReview?, onSubmit: @escaping (Int, String) -> Void) {
        self.stationId = stationId
        self.userId = userId
        self.username = username
        self.existingReview = existingReview
        self.onSubmit = onSubmit
        
        // Initialize state properties with existing review data if available
        _rating = State(initialValue: existingReview?.rating ?? 0)
        _reviewText = State(initialValue: existingReview?.comment ?? "")
        
        if let review = existingReview {
            _dateCreated = State(initialValue: review.datePosted)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Your Rating")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tap to rate:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.title)
                                    .foregroundColor(.yellow)
                                    .onTapGesture {
                                        rating = star
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                        
                        // Show description based on rating
                        if rating > 0 {
                            Text(ratingDescription(for: rating))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
                
                Section(header: Text("Your Review (Optional)")) {
                    TextEditor(text: $reviewText)
                        .frame(minHeight: 150)
                }
                
                Section {
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(formattedDate(dateCreated))
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button(action: {
                        onSubmit(rating, reviewText)
                        dismiss()
                    }) {
                        Text("Submit Review")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(rating > 0 ? Color.blue : Color.gray)
                            .cornerRadius(8)
                    }
                    .disabled(rating == 0)
                }
            }
            .navigationTitle(existingReview != nil ? "Edit Review" : "Leave a Review")
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
        }
    }
    
    // Get a description for each rating level
    private func ratingDescription(for rating: Int) -> String {
        switch rating {
        case 1: return "Poor - Would not recommend"
        case 2: return "Fair - Has some issues"
        case 3: return "Average - Okay"
        case 4: return "Good - Recommended"
        case 5: return "Excellent - Highly recommended!"
        default: return ""
        }
    }
    
    // Format the date in a readable way
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ReviewFormView(
        stationId: "test-id",
        userId: "user-id",
        username: "TestUser",
        existingReview: nil,
        onSubmit: { _, _ in }
    )
}
