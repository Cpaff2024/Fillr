import SwiftUI // Needed for Color if you add it later or other UI properties

// Define the Badge structure
struct Badge: Identifiable, Hashable {
    let id: String // Use a unique string ID for each badge type
    let name: String
    let description: String
    let iconName: String // SF Symbol name for the badge icon
    // Optional: Add criteria value for display or sorting later
    // let criteriaValue: Int? = nil
}

// Define the specific badges available in the app
struct Badges {
    // --- Refill Badges ---
    static let firstRefill = Badge(id: "refill_1", name: "First Refill", description: "Logged your first bottle refill!", iconName: "drop.fill")
    static let tenRefills = Badge(id: "refill_10", name: "Hydration Helper", description: "Logged 10 bottle refills.", iconName: "10.circle.fill")
    static let fiftyRefills = Badge(id: "refill_50", name: "Eco Hydrator", description: "Logged 50 bottle refills.", iconName: "50.circle.fill")
    // Add more refill milestones (100, 250, etc.)

    // --- Station Badges ---
    static let firstStation = Badge(id: "station_1", name: "Map Pioneer", description: "Added your first station.", iconName: "mappin.and.ellipse")
    static let fiveStations = Badge(id: "station_5", name: "Community Mapper", description: "Added 5 stations.", iconName: "5.circle.fill")
    static let tenStations = Badge(id: "station_10", name: "Mapping Master", description: "Added 10 stations.", iconName: "10.circle.fill")
    // Add more station milestones (25, 50, etc.)

    // --- Other Potential Badges ---
    // static let firstReview = Badge(id: "review_1", name: "Review Starter", description: "Wrote your first review.", iconName: "star.bubble")
    // static let earlyAdopter = Badge(id: "early_1", name: "Early Adopter", description: "Joined during the beta phase.", iconName: "sparkles")

    // Array of all possible badges (useful for checking criteria)
    static let allBadges: [Badge] = [
        firstRefill, tenRefills, fiftyRefills,
        firstStation, fiveStations, tenStations
        // Add others here as they are defined
        // , firstReview, earlyAdopter // Uncomment when defined
    ]

    // Optional: Function to get a badge by its ID if needed elsewhere
    static func badge(withId id: String) -> Badge? {
        return allBadges.first { $0.id == id }
    }
}
