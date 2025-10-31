import SwiftUI

struct GreetingBannerView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption) // Use a smaller font
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule() // Use a capsule shape
                    .fill(.ultraThinMaterial) // Use a blurred background material
                    .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
            )
            .foregroundColor(.primary) // Use primary text color for better contrast
            .lineLimit(1) // Prevent text wrapping
            .minimumScaleFactor(0.8) // Allow text to shrink slightly if needed
    }
}

#Preview {
    GreetingBannerView(message: "Good Afternoon, Water Hero!")
        .padding() // Add padding for preview visibility
        .background(Color.gray.opacity(0.2))
}
