import SwiftUI
import MapKit // Keep if StationAnnotation uses it, otherwise can remove

struct StationMarkerView: View {
    let station: RefillStation

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) { // Align overlay to bottom trailing
                // Main colored circle based on location type
                Circle()
                    .fill(station.locationType.markerColor)
                    .frame(width: 36, height: 36)
                    .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)

                // Location type icon (center)
                Image(systemName: station.locationType.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white) // Make icon white for contrast

                // --- NEW: Overlay for Business Listings ---
                if station.listingType == .business {
                    Image(systemName: "building.2.crop.circle.fill") // Example: building icon
                        .font(.system(size: 14)) // Smaller size
                        .foregroundColor(.black) // Or another contrasting color
                        .padding(2)
                        .background(Circle().fill(.white.opacity(0.8))) // Semi-transparent white background
                        .offset(x: 4, y: 4) // Adjust offset slightly
                }
                // --- END NEW ---
            }

            // Rating indicator if available (keep this part)
            if let rating = station.averageRating, station.ratingsCount > 0 {
                HStack(spacing: 1) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.yellow)
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().stroke(Color.gray.opacity(0.3), lineWidth: 0.5))
                .offset(y: -4)
            }
        }
        .scaleEffect(1.1) // Keep optional scaling
    }
}

// StationAnnotation unchanged
struct StationAnnotation: View {
    let station: RefillStation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            StationMarkerView(station: station)
        }
        .buttonStyle(.plain)
    }
}

// Preview updated to show different listing types
struct StationMarkerView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 30) {
            // User-added Fountain
            StationMarkerView(
                station: RefillStation(name: "Park Fountain", description: "", locationType: .waterFountain, cost: .free, limitations: "", addedByUserID: "user1", listingType: .user)
            )
            // Business Cafe
             StationMarkerView(
                station: RefillStation(name: "Busy Cafe", description: "", locationType: .cafe, cost: .purchaseRequired, limitations: "", addedByUserID: "business1", listingType: .business, averageRating: 4.5, ratingsCount: 12)
            )
             // Business Pub
              StationMarkerView(
                 station: RefillStation(name: "Local Pub", description: "", locationType: .pub, cost: .paid, limitations: "", addedByUserID: "business2", listingType: .business)
             )
            // User-added Other
            StationMarkerView(
                station: RefillStation(name: "Community Tap", description: "", locationType: .other, cost: .free, limitations: "", addedByUserID: "user2", listingType: .user, averageRating: 3.1, ratingsCount: 4)
            )
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .previewLayout(.sizeThatFits)
    }
}
