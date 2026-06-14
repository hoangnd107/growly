import Foundation
import CoreLocation

/// One-shot current-location capture + reverse geocoding for tagging notes.
/// Needs NSLocationWhenInUseUsageDescription (set in project.yml). No special
/// entitlement, so it works on a free sideload.
@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
  @Published private(set) var placeName: String?
  @Published private(set) var latitude: Double?
  @Published private(set) var longitude: Double?
  @Published private(set) var isResolving = false

  private let manager = CLLocationManager()

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  func capture() {
    isResolving = true
    manager.requestWhenInUseAuthorization()
    manager.requestLocation()
  }

  func clear() {
    placeName = nil
    latitude = nil
    longitude = nil
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    Task { @MainActor in
      self.latitude = location.coordinate.latitude
      self.longitude = location.coordinate.longitude
      let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
      if let placemark = placemarks?.first {
        self.placeName = placemark.name
          ?? placemark.locality
          ?? placemark.administrativeArea
          ?? placemark.country
      }
      self.isResolving = false
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    Task { @MainActor in self.isResolving = false }
  }
}
