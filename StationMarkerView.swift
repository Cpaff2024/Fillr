import SwiftUI
import MapKit

struct StationMarkerView: View {
    let station: RefillStation
    
    var body: some View {
        VStack(spacing: 0) {
            // Icon with colored background based on station type
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 36, height: 36)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                
                Image(systemName: station.locationType.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            }
            
            // Rating indicator if available
            if let rating = station.averageRating, station.ratingsCount > 0 {
                HStack(spacing: 1) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                    
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 8, weight: .bold))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .offset(y: -4)
            }
        }
    }
}

// Use this as a custom annotation in your MapView
struct StationAnnotation: View {
    let station: RefillStation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            StationMarkerView(station: station)
        }
    }
}

// Preview
struct StationMarkerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Station with rating
            StationMarkerView(
                station: RefillStation(
                    id: UUID(),
                    coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    name: "Rated Station",
                    description: "",
                    locationType: .waterFountain,
                    cost: .free,
                    limitations: "",
                    photos: [],
                    photoIDs: [],
                    dateAdded: Date(),
                    addedByUserID: "",
                    averageRating: 4.5,
                    ratingsCount: 12
                )
            )
            
            // Station without rating
            StationMarkerView(
                station: RefillStation(
                    id: UUID(),
                    coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    name: "Unrated Station",
                    description: "",
                    locationType: .shop,
                    cost: .purchaseRequired, // Make sure this uses purchaseRequired, not purchase
                    limitations: "",
                    photos: [],
                    photoIDs: [],
                    dateAdded: Date(),
                    addedByUserID: ""
                )
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
