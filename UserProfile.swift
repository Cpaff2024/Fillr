import Foundation
import SwiftUI

struct UserProfile {
    var id: String = UUID().uuidString
    var username: String = "Water Hero"
    var profileImageName: String? = nil
    var dateJoined: Date = Date()
    
    // Statistics
    var stationsAdded: Int = 0
    var totalContributions: Int = 0 // Stations + reviews, etc.
    
    // Calculated metrics
    var estimatedPlasticBottlesSaved: Int {
        // Rough estimate: each station saves ~5 bottles per day since being added
        let calendar = Calendar.current
        let daysActive = calendar.dateComponents([.day], from: dateJoined, to: Date()).day ?? 0
        return stationsAdded * 5 * max(daysActive, 1)
    }
    
    var environmentalImpact: String {
        // Rough formula: each bottle is ~0.5L of water and saves ~82g of CO2
        let co2Saved = Float(estimatedPlasticBottlesSaved) * 0.082
        if co2Saved < 1.0 {
            return "\(Int(co2Saved * 1000))g of CO2"
        } else {
            return String(format: "%.1f kg of CO2", co2Saved)
        }
    }
    
    // Settings
    var defaultSearchRadius: Double = 1.0
    var useDarkMode: Bool = false
    var notificationsEnabled: Bool = true
    
    // Achievement badges
    enum Badge: String, CaseIterable, Identifiable {
        case firstStation = "First Station Added"
        case fiveStations = "5 Stations Added"
        case tenStations = "10 Stations Added"
        case earlyAdopter = "Early Adopter"
        
        var id: String { self.rawValue }
        
        var iconName: String {
            switch self {
            case .firstStation: return "1.circle.fill"
            case .fiveStations: return "5.circle.fill"
            case .tenStations: return "10.circle.fill"
            case .earlyAdopter: return "star.fill"
            }
        }
        
        var description: String {
            switch self {
            case .firstStation: return "Added your first water refill station"
            case .fiveStations: return "Added 5 water refill stations"
            case .tenStations: return "Added 10 water refill stations"
            case .earlyAdopter: return "Joined during the app's first month"
            }
        }
    }
    
    var earnedBadges: [Badge] {
        var badges: [Badge] = []
        
        // Check for station-related badges
        if stationsAdded >= 1 {
            badges.append(.firstStation)
        }
        if stationsAdded >= 5 {
            badges.append(.fiveStations)
        }
        if stationsAdded >= 10 {
            badges.append(.tenStations)
        }
        
        // Check if user is an early adopter
        let calendar = Calendar.current
        let appLaunchDate = Calendar.current.date(from: DateComponents(year: 2025, month: 3, day: 1))!
        let oneMonthLater = calendar.date(byAdding: .month, value: 1, to: appLaunchDate)!
        
        if dateJoined < oneMonthLater {
            badges.append(.earlyAdopter)
        }
        
        return badges
    }
    
    // Mock user for preview and initial state
    static var mockUser: UserProfile {
        var user = UserProfile()
        user.username = "Water Hero"
        user.dateJoined = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        user.stationsAdded = 7
        user.totalContributions = 12
        return user
    }
}
