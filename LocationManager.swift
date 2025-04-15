import Foundation
import CoreLocation
import SwiftUI

// This class handles getting the user's location
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // The actual system location manager
    private let locationManager = CLLocationManager()
    
    // The user's current location (when we know it)
    @Published var location: CLLocation?
    
    // Whether the user has given us permission to use their location
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // Set up the location manager when created
    override init() {
        super.init()
        locationManager.delegate = self
        // Set to best accuracy for finding nearby water stations
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Only update position when user moves at least 10 meters
        locationManager.distanceFilter = 10
    }
    
    // Call this to start getting the user's location
    func requestLocation() {
        // First ask for permission to use location
        locationManager.requestWhenInUseAuthorization()
        // Then start getting updates about where the user is
        locationManager.startUpdatingLocation()
    }
    
    // This is called whenever we get a new location for the user
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Take the most recent location update
        guard let location = locations.last else { return }
        self.location = location
    }
    
    // This is called if there's an error getting the user's location
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    // This is called when the user changes whether we can access their location
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        // If we now have permission, start getting their location
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
}
