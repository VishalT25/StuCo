import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var locationName: String = "Loading..." // Default until GPS or manual set
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var manualCityOverride: String?

    private var geocoder = CLGeocoder()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer // We don't need super high accuracy for city-level weather
    }

    func requestLocationPermission() {
        if manualCityOverride == nil { // Only request if no manual override
            manager.requestWhenInUseAuthorization()
        }
    }
    
    func setManualLocation(cityName: String) {
        self.manualCityOverride = cityName
        self.locationName = cityName
        self.location = nil // Clear GPS location if manual is set
        manager.stopUpdatingLocation() // Stop GPS if it was running
    }

    func clearManualLocationAndUseGPS() {
        self.manualCityOverride = nil
        self.locationName = "Loading..." // Reset for GPS
        requestLocationPermission() // Re-request if needed and start updating
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func startUpdatingLocation() {
        if manualCityOverride == nil { // Only start GPS if no manual override
            manager.startUpdatingLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manualCityOverride == nil { // Only react to GPS changes if no manual override
            switch authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.startUpdatingLocation()
            case .denied, .restricted:
                self.locationName = "Location Access Denied"
            case .notDetermined:
                self.locationName = "Loading..."
            @unknown default:
                self.locationName = "Location Unavailable"
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if manualCityOverride != nil { return } // Ignore GPS updates if manual city is set

        location = locations.first
        manager.stopUpdatingLocation() // Stop after getting one location to save battery

        if let location = locations.first {
            geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
                guard let self = self, self.manualCityOverride == nil else { return } // Check override again
                if let error = error {
                     ("Error reverse geocoding: \(error.localizedDescription)")
                    self.locationName = "Unknown Location"
                    return
                }
                if let placemark = placemarks?.first {
                    self.locationName = placemark.locality ?? placemark.name ?? "Unknown Area"
                } else {
                    self.locationName = "Unknown Location"
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if manualCityOverride != nil { return } // Ignore GPS errors if manual city is set
         ("Failed to find user's location: \(error.localizedDescription)")
        // Could set a default location or show an error message
        self.locationName = "Location Error"
    }
}
