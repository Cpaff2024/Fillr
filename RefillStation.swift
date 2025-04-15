import Foundation
import CoreLocation
import SwiftUI

struct RefillStation: Identifiable, Hashable {
    var id: UUID
    var coordinate: CLLocationCoordinate2D
    var name: String
    var description: String
    var locationType: LocationType
    var cost: RefillCost
    var limitations: String
    var photos: [UIImage] = []  // For local stations being added
    var photoIDs: [String] = [] // For stations loaded from Firebase
    var dateAdded: Date
    var addedByUserID: String

    // Rating information
    var averageRating: Double?
    var ratingsCount: Int = 0

    // Offline Mode Properties
    var manualAddress: String?
    var manualDescription: String?

    // Different types of locations where you can refill water
    enum LocationType: String, CaseIterable {
        case waterFountain = "Water Fountain"
        case cafe = "Café"
        case restaurant = "Restaurant"
        case shop = "Shop"
        case publicSpace = "Public Space"
        case other = "Other"

        // The icon to show on the map for each type
        var icon: String {
            switch self {
            case .waterFountain: return "drop.fill"
            case .cafe: return "cup.and.saucer.fill"
            case .restaurant: return "fork.knife"
            case .shop: return "bag.fill"
            case .publicSpace: return "building.columns.fill"
            case .other: return "questionmark.circle.fill"
            }
        }
    }

    // Different cost options for refilling
    enum RefillCost: String, CaseIterable {
        case free = "Free"
        case purchaseRequired = "With Purchase"  // Changed to match existing code
        case paid = "Paid"

        // Background color for the cost label
        var backgroundColor: Color {
            switch self {
            case .free: return Color.green.opacity(0.2)
            case .purchaseRequired: return Color.orange.opacity(0.2)
            case .paid: return Color.blue.opacity(0.2)
            }
        }

        // Color for the map marker
        var markerColor: Color {
            switch self {
            case .free: return .green
            case .purchaseRequired: return .orange
            case .paid: return .blue
            }
        }
    }

    // Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Equatable implementation
    static func == (lhs: RefillStation, rhs: RefillStation) -> Bool {
        lhs.id == rhs.id
    }
}
