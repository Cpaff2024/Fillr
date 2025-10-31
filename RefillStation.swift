import Foundation
import CoreLocation
import SwiftUI // Needed for Color in Enums
import FirebaseFirestore // Import for GeoPoint/Timestamp

// Define the Listing Type Enum
enum ListingType: String, Codable, CaseIterable {
    case user = "User Added"
    case business = "Business Listing"
}

// Make struct Codable for saving/loading drafts
struct RefillStation: Identifiable, Hashable, Codable {
    var id: UUID // Keep UUID for consistency with previous code
    var coordinate: CLLocationCoordinate2D? // Optional for drafts
    var name: String
    var description: String
    var locationType: LocationType // e.g., Cafe, Fountain, Pub
    var cost: RefillCost
    var limitations: String
    var photoIDs: [String] = [] // Store paths from Firebase
    var dateAdded: Date
    var addedByUserID: String // Store who added/drafted

    // --- NEW FIELD ---
    var listingType: ListingType = .user // Default to user-added

    // Existing fields
    var averageRating: Double?
    var ratingsCount: Int = 0
    var isCarAccessible: Bool?
    var isDraft: Bool = false // Different from listingType, indicates saved locally vs submitted

    var manualAddress: String?
    var manualDescription: String?

    // --- Codable Conformance ---
    // Add listingType to coding keys
    private enum CodingKeys: String, CodingKey {
        case id, coordinateData, name, description, locationType, cost, limitations, photoIDs, dateAdded, addedByUserID, listingType, averageRating, ratingsCount, isCarAccessible, isDraft, manualAddress, manualDescription
    }

    // Helper struct for encoding/decoding CLLocationCoordinate2D
    struct CoordinateData: Codable, Hashable {
        var latitude: Double
        var longitude: Double
    }

    // Computed property to bridge CoordinateData and CLLocationCoordinate2D?
    var coordinateData: CoordinateData? {
        get {
            guard let coordinate = coordinate else { return nil }
            return CoordinateData(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }

    // --- LocationType Enum (Keep all types for filtering/display) ---
    enum LocationType: String, CaseIterable, Codable {
        case waterFountain = "Water Fountain"
        case cafe = "Café"
        case restaurant = "Restaurant"
        case shop = "Shop"
        case pub = "Pub"
        case publicSpace = "Public Space" // e.g., Parks, Libraries with fountains
        case other = "Other" // For user additions not fitting elsewhere

        var icon: String {
            switch self {
            case .waterFountain: return "drop.fill"
            case .cafe: return "cup.and.saucer.fill"
            case .restaurant: return "fork.knife"
            case .shop: return "bag.fill"
            case .pub: return "wineglass.fill"
            case .publicSpace: return "building.columns.fill"
            case .other: return "questionmark.circle.fill"
            }
        }

        // Color for map markers
        var markerColor: Color {
            switch self {
            case .waterFountain: return .cyan // Changed for better distinction
            case .cafe: return .brown
            case .restaurant: return .red
            case .shop: return .purple
            case .pub: return .orange
            case .publicSpace: return .green
            case .other: return .gray
            }
        }
    }

    // --- RefillCost Enum ---
    enum RefillCost: String, CaseIterable, Codable {
        case free = "Free"
        case purchaseRequired = "With Purchase"
        case paid = "Paid"

        var backgroundColor: Color {
            switch self {
            case .free: return Color.green.opacity(0.2)
            case .purchaseRequired: return Color.orange.opacity(0.2)
            case .paid: return Color.blue.opacity(0.2)
            }
        }
    }

    // --- Hashable & Equatable ---
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: RefillStation, rhs: RefillStation) -> Bool { lhs.id == rhs.id }

    // --- Initializers ---
    // Add listingType parameter with default
    init(id: UUID = UUID(), coordinate: CLLocationCoordinate2D? = nil, name: String, description: String, locationType: LocationType, cost: RefillCost, limitations: String, photoIDs: [String] = [], dateAdded: Date = Date(), addedByUserID: String, listingType: ListingType = .user, averageRating: Double? = nil, ratingsCount: Int = 0, isCarAccessible: Bool? = nil, isDraft: Bool = false, manualAddress: String? = nil, manualDescription: String? = nil) {
        self.id = id
        self.coordinate = coordinate
        self.name = name
        self.description = description
        self.locationType = locationType
        self.cost = cost
        self.limitations = limitations
        self.photoIDs = photoIDs
        self.dateAdded = dateAdded
        self.addedByUserID = addedByUserID
        self.listingType = listingType // Assign new field
        self.averageRating = averageRating
        self.ratingsCount = ratingsCount
        self.isCarAccessible = isCarAccessible
        self.isDraft = isDraft
        self.manualAddress = manualAddress
        self.manualDescription = manualDescription
    }

    // --- Custom Decoder Initializer (Handles new listingType) ---
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        locationType = try container.decode(LocationType.self, forKey: .locationType)
        cost = try container.decode(RefillCost.self, forKey: .cost)
        limitations = try container.decode(String.self, forKey: .limitations)
        photoIDs = try container.decode([String].self, forKey: .photoIDs)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        addedByUserID = try container.decode(String.self, forKey: .addedByUserID)
        // Decode listingType, default to .user if missing for backward compatibility
        listingType = try container.decodeIfPresent(ListingType.self, forKey: .listingType) ?? .user
        averageRating = try container.decodeIfPresent(Double.self, forKey: .averageRating)
        ratingsCount = try container.decode(Int.self, forKey: .ratingsCount)
        isCarAccessible = try container.decodeIfPresent(Bool.self, forKey: .isCarAccessible)
        isDraft = try container.decode(Bool.self, forKey: .isDraft)
        manualAddress = try container.decodeIfPresent(String.self, forKey: .manualAddress)
        manualDescription = try container.decodeIfPresent(String.self, forKey: .manualDescription)

        // Decode coordinateData if present
        if let coordData = try container.decodeIfPresent(CoordinateData.self, forKey: .coordinateData) {
            coordinate = CLLocationCoordinate2D(latitude: coordData.latitude, longitude: coordData.longitude)
        } else {
            coordinate = nil
        }
    }

    // --- Custom Encoder Function (Include listingType) ---
     func encode(to encoder: Encoder) throws {
         var container = encoder.container(keyedBy: CodingKeys.self)
         try container.encode(id, forKey: .id)
         try container.encode(coordinateData, forKey: .coordinateData)
         try container.encode(name, forKey: .name)
         try container.encode(description, forKey: .description)
         try container.encode(locationType, forKey: .locationType)
         try container.encode(cost, forKey: .cost)
         try container.encode(limitations, forKey: .limitations)
         try container.encode(photoIDs, forKey: .photoIDs)
         try container.encode(dateAdded, forKey: .dateAdded)
         try container.encode(addedByUserID, forKey: .addedByUserID)
         try container.encode(listingType, forKey: .listingType) // Encode new field
         try container.encodeIfPresent(averageRating, forKey: .averageRating)
         try container.encode(ratingsCount, forKey: .ratingsCount)
         try container.encodeIfPresent(isCarAccessible, forKey: .isCarAccessible)
         try container.encode(isDraft, forKey: .isDraft)
         try container.encodeIfPresent(manualAddress, forKey: .manualAddress)
         try container.encodeIfPresent(manualDescription, forKey: .manualDescription)
     }


    // --- Static helper for parsing from Firestore (Include listingType) ---
     static func fromFirestoreDocument(_ document: QueryDocumentSnapshot) -> RefillStation? {
         let data = document.data()
         guard
             let location = data["location"] as? GeoPoint,
             let name = data["name"] as? String,
             let typeString = data["type"] as? String,
             let costString = data["cost"] as? String,
             let description = data["description"] as? String,
             let limitations = data["limitations"] as? String,
             let photoIDs = data["photoIDs"] as? [String],
             let timestamp = data["dateAdded"] as? Timestamp,
             let addedBy = data["addedBy"] as? String
         else {
              print("⚠️ Failed to parse station document \(document.documentID). Missing required fields for a final station.")
             return nil
         }

         let locationType = RefillStation.LocationType(rawValue: typeString) ?? .other
         let costType = RefillStation.RefillCost(rawValue: costString) ?? .free

         // Parse listingType, default to .user if field doesn't exist in Firestore yet
         let listingTypeString = data["listingType"] as? String
         let listingType = ListingType(rawValue: listingTypeString ?? "") ?? .user

         let isCarAccessible = data["isCarAccessible"] as? Bool
         let averageRating = data["averageRating"] as? Double
         let ratingsCount = data["ratingsCount"] as? Int ?? 0
         let manualAddress = data["manualAddress"] as? String
         let manualDescription = data["manualDescription"] as? String

         return RefillStation(
             id: UUID(uuidString: document.documentID) ?? UUID(),
             coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
             name: name,
             description: description,
             locationType: locationType,
             cost: costType,
             limitations: limitations,
             photoIDs: photoIDs,
             dateAdded: timestamp.dateValue(),
             addedByUserID: addedBy,
             listingType: listingType, // Assign parsed listingType
             averageRating: averageRating,
             ratingsCount: ratingsCount,
             isCarAccessible: isCarAccessible,
             isDraft: false, // Mark as NOT a draft when fetching from Firestore
             manualAddress: manualAddress,
             manualDescription: manualDescription
         )
     }
}
