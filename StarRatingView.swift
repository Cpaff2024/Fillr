import SwiftUI

struct StarRatingView: View {
    let rating: Double
    let maxRating: Int
    let size: CGFloat
    let spacing: CGFloat
    let color: Color
    
    init(
        rating: Double,
        maxRating: Int = 5,
        size: CGFloat = 16,
        spacing: CGFloat = 0,
        color: Color = .yellow
    ) {
        self.rating = rating
        self.maxRating = maxRating
        self.size = size
        self.spacing = spacing
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: starType(for: star))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundColor(color)
            }
        }
    }
    
    private func starType(for position: Int) -> String {
        if Double(position) <= rating {
            return "star.fill"
        } else if Double(position) - 0.5 <= rating {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}
