import Foundation
import CoreLocation
import SwiftUI // Needed for @Published

// This class handles getting the user's location
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // The actual system location manager
    private let clLocationManager = CLLocationManager() // Renamed to avoid confusion with the class name
    
    // The user's current location (when we know it)
    @Published var location: CLLocation?
    
    // Whether the user has given us permission to use their location
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // Set up the location manager when created
    override init() {
        super.init()
        clLocationManager.delegate = self
        // Set to best accuracy for finding nearby water stations
        clLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Only update position when user moves at least 10 meters
        clLocationManager.distanceFilter = 10
        
        // Check initial authorization status
        self.authorizationStatus = clLocationManager.authorizationStatus
        print("LocationManager init: Initial authorizationStatus = \(self.authorizationStatus.rawValue)")
    }
    
    // Call this to start getting the user's location
    func requestLocationPermissionAndUpdates() {
        print("LocationManager: requestLocationPermissionAndUpdates called.")
        
        switch clLocationManager.authorizationStatus {
        case .notDetermined:
            print("LocationManager: Authorization not determined. Requesting WhenInUse.")
            clLocationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            print("LocationManager: Authorization restricted or denied. Cannot start location updates.")
            // Optionally, inform the user they need to enable permissions in Settings.
            // You might want to publish an error or state for the UI to react to.
            self.location = nil // Ensure location is nil if denied
        case .authorizedAlways, .authorizedWhenInUse:
            print("LocationManager: Already authorized. Starting location updates.")
            clLocationManager.startUpdatingLocation()
        @unknown default:
            print("LocationManager: Unknown authorization status.")
            clLocationManager.requestWhenInUseAuthorization()
        }
    }
    
    // This is called whenever we get a new location for the user
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        // Check if the new location is significantly different or more accurate
        // to avoid redundant updates if location is already recent and good.
        // For now, we update directly.
        self.location = newLocation
        print("LocationManager: Location updated to Lat: \(newLocation.coordinate.latitude), Lon: \(newLocation.coordinate.longitude)")
    }
    
    // This is called if there's an error getting the user's location
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager: Failed to get location: \(error.localizedDescription)")
        // You might want to publish this error for the UI.
        // self.location = nil // Or handle appropriately
    }
    
    // This is called when the user changes whether we can access their location
    // (e.g., from the Settings app or the initial prompt)
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus // Update published status
        print("LocationManager: locationManagerDidChangeAuthorization callback. New status: \(self.authorizationStatus.rawValue)")
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("LocationManager: Permission granted via didChangeAuthorization. Starting location updates.")
            clLocationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("LocationManager: Permission denied or restricted via didChangeAuthorization.")
            // User has explicitly denied or system has restricted.
            // Stop updates and clear location if necessary.
            clLocationManager.stopUpdatingLocation()
            self.location = nil
            // You should inform the user that the app needs location permissions.
        case .notDetermined:
            print("LocationManager: Authorization status changed to notDetermined (should be rare here unless reset).")
        @unknown default:
            print("LocationManager: Unknown authorization status in didChangeAuthorization.")
        }
    }
}
