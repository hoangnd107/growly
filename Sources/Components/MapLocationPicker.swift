import SwiftUI
import MapKit
import CoreLocation

/// A map sheet for picking a place: search an address, tap anywhere to drop a
/// pin, or center on your current location. The chosen place (name + coordinate)
/// is returned via `onPick`. Used to add one of possibly many locations to a note.
struct MapLocationPicker: View {
  var onPick: (_ name: String, _ latitude: Double, _ longitude: Double) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var camera: MapCameraPosition = .automatic
  @State private var picked: CLLocationCoordinate2D?
  @State private var name: String = ""
  @State private var query: String = ""
  @State private var searching = false
  @State private var message: String?

  private let geocoder = CLGeocoder()
  /// Held so we can ask for "when in use" permission to show the blue user dot.
  @State private var locationManager = CLLocationManager()

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        searchBar
        mapView
        footer
      }
      .navigationTitle(L("Choose location"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(L("Cancel")) { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button(L("Add")) { confirm() }
            .fontWeight(.semibold)
            .disabled(picked == nil)
        }
      }
      .onAppear { locationManager.requestWhenInUseAuthorization() }
    }
  }

  // MARK: Search

  private var searchBar: some View {
    HStack(spacing: DLSpace.sm) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(DLColor.textSecondary)
      TextField(L("Search address or place"), text: $query)
        .textInputAutocapitalization(.words)
        .submitLabel(.search)
        .onSubmit(runSearch)
      if searching {
        ProgressView()
      } else if !query.isEmpty {
        Button {
          query = ""
        } label: {
          Image(systemName: "xmark.circle.fill").foregroundStyle(DLColor.textTertiary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(DLSpace.md)
    .background(DLColor.surfaceElevated)
  }

  // MARK: Map

  private var mapView: some View {
    MapReader { proxy in
      Map(position: $camera) {
        UserAnnotation()
        if let picked {
          Marker(name.isEmpty ? L("Selected location") : name, coordinate: picked)
            .tint(.red)
        }
      }
      .mapControls {
        MapUserLocationButton()
        MapCompass()
      }
      .onTapGesture { point in
        if let coord = proxy.convert(point, from: .local) {
          select(coord)
        }
      }
      .overlay(alignment: .top) {
        if let message {
          Text(message)
            .font(.dl(.caption, weight: .medium))
            .foregroundStyle(DLColor.textPrimary)
            .padding(.horizontal, DLSpace.md)
            .padding(.vertical, DLSpace.sm)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, DLSpace.sm)
        }
      }
    }
  }

  // MARK: Footer (name + hint)

  private var footer: some View {
    VStack(spacing: DLSpace.sm) {
      if picked != nil {
        HStack(spacing: DLSpace.sm) {
          Image(systemName: "mappin.circle.fill")
            .font(.system(size: 22))
            .foregroundStyle(.red)
          TextField(L("Location name"), text: $name)
            .font(.dl(.body, weight: .medium))
            .foregroundStyle(DLColor.textPrimary)
        }
      } else {
        Text(L("Search an address, or tap the map to drop a pin."))
          .font(.dl(.subheadline))
          .foregroundStyle(DLColor.textSecondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity)
      }
    }
    .padding(DLSpace.md)
    .background(DLColor.surfaceElevated)
  }

  // MARK: Actions

  private func runSearch() {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return }
    searching = true
    message = nil
    geocoder.geocodeAddressString(q) { placemarks, _ in
      searching = false
      guard let placemark = placemarks?.first, let location = placemark.location else {
        message = L("No results found.")
        return
      }
      let coordinate = location.coordinate
      name = placemark.name ?? placemark.locality ?? q
      picked = coordinate
      camera = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 1200, longitudinalMeters: 1200))
    }
  }

  private func select(_ coordinate: CLLocationCoordinate2D) {
    picked = coordinate
    name = ""
    message = nil
    Haptics.selection()
    geocoder.reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) { placemarks, _ in
      if let placemark = placemarks?.first {
        name = placemark.name ?? placemark.locality ?? placemark.administrativeArea ?? ""
      }
    }
  }

  private func confirm() {
    guard let picked else { return }
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    onPick(trimmed.isEmpty ? L("Pinned location") : trimmed, picked.latitude, picked.longitude)
    dismiss()
  }
}
