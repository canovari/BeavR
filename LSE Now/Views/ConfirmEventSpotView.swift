import SwiftUI
import MapKit
import CoreLocation
import Combine

struct ConfirmEventSpotView: View {
    @Binding var locationText: String
    @State private var region: MKCoordinateRegion
    @State private var cameraPosition: MapCameraPosition
    @State private var searchError: String?
    @State private var geocodeWorkItem: DispatchWorkItem?
    @State private var shouldSkipNextReverseGeocode = false
    @State private var isGeocoding = false
    @State private var hasCenteredOnUser = false
    @FocusState private var isAddressFieldFocused: Bool

    private let geocoder = CLGeocoder()
    let initialCoordinate: CLLocationCoordinate2D?
    let onConfirm: (CLLocationCoordinate2D) -> Void

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var locationManager: LocationManager

    private let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)

    init(initialCoordinate: CLLocationCoordinate2D? = nil,
         locationText: Binding<String>,
         onConfirm: @escaping (CLLocationCoordinate2D) -> Void) {
        self.initialCoordinate = initialCoordinate
        self.onConfirm = onConfirm
        self._locationText = locationText

        if let coord = initialCoordinate {
            let initialRegion = MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )
            _region = State(initialValue: initialRegion)
            _cameraPosition = State(initialValue: .region(initialRegion))
        } else {
            let initialRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 51.5145, longitude: -0.1160),
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )
            _region = State(initialValue: initialRegion)
            _cameraPosition = State(initialValue: .region(initialRegion))
        }
    }

    private var isLocationAuthorized: Bool {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            headerSection
            searchSection
            errorMessage
            mapContent
            selectedAddressLabel
            Spacer()
            confirmButton
        }
        .padding()
        .navigationTitle("Map Pin")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            locationManager.refreshLocation()

            if let coord = initialCoordinate, locationText.isEmpty {
                reverseGeocode(for: coord)
            }

            if initialCoordinate == nil {
                centerOnUserIfAvailable(shouldReverseGeocode: locationText.isEmpty)
            }
        }
        .onDisappear {
            geocodeWorkItem?.cancel()
            geocoder.cancelGeocode()
        }
        .onReceive(locationManager.$latestLocation.compactMap { $0 }) { location in
            guard initialCoordinate == nil, !hasCenteredOnUser else { return }
            centerMap(on: location.coordinate, shouldReverseGeocode: locationText.isEmpty)
            hasCenteredOnUser = true
        }
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                locationManager.refreshLocation()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Select Event Location")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Search for an address or drag the map to drop the pin.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchSection: some View {
        HStack(spacing: 8) {
            TextField("Search for an address", text: $locationText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .submitLabel(.search)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.words)
                .focused($isAddressFieldFocused)
                .onSubmit { searchForAddress() }

            Button {
                searchForAddress()
            } label: {
                if isGeocoding {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image(systemName: "magnifyingglass")
                }
            }
            .frame(width: 44, height: 44)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(locationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGeocoding)
        }
    }

    @ViewBuilder
    private var errorMessage: some View {
        if let searchError {
            Text(searchError)
                .font(.footnote)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var mapContent: some View {
        ZStack {
            Map(position: $cameraPosition, interactionModes: .all) {
                if isLocationAuthorized {
                    UserAnnotation()
                }
            }
            .frame(height: 360)
            .cornerRadius(12)
            .shadow(radius: 3)
            .onMapCameraChange { context in
                guard let newRegion = context.region as MKCoordinateRegion? else { return }
                region = newRegion
                regionCenterChanged(to: newRegion.center)
            }
            .mapControls {
                if isLocationAuthorized {
                    MapUserLocationButton()
                }
            }

            Circle()
                .fill(Color("LSERed"))
                .frame(width: 14, height: 14)
                .overlay(
                    Circle().stroke(Color.white, lineWidth: 2)
                )
                .shadow(radius: 1)
        }
    }

    @ViewBuilder
    private var selectedAddressLabel: some View {
        if !locationText.isEmpty {
            Text(locationText)
                .font(.footnote)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var confirmButton: some View {
        Button {
            confirmSelection()
        } label: {
            Text("Confirm Location")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("LSERed"))
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .disabled(isGeocoding)
    }

    private func centerOnUserIfAvailable(shouldReverseGeocode: Bool) {
        guard let coordinate = locationManager.latestLocation?.coordinate else { return }
        centerMap(on: coordinate, shouldReverseGeocode: shouldReverseGeocode)
        hasCenteredOnUser = true
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D, shouldReverseGeocode: Bool) {
        shouldSkipNextReverseGeocode = true

        let newRegion = MKCoordinateRegion(center: coordinate, span: defaultSpan)

        withAnimation {
            region = newRegion
            cameraPosition = .region(newRegion)
        }

        if shouldReverseGeocode {
            reverseGeocode(for: coordinate)
        }
    }

    private func searchForAddress() {
        let query = locationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        geocodeWorkItem?.cancel()
        geocoder.cancelGeocode()
        isGeocoding = true
        searchError = nil

        geocoder.geocodeAddressString(query) { placemarks, error in
            DispatchQueue.main.async {
                isGeocoding = false
            }

            if let error = error as? CLError, error.code == .geocodeCanceled {
                return
            }

            guard let placemark = placemarks?.first,
                  let location = placemark.location,
                  error == nil else {
                DispatchQueue.main.async {
                    searchError = "Unable to find that address. Try again."
                }
                return
            }

            let coordinate = location.coordinate

            DispatchQueue.main.async {
                shouldSkipNextReverseGeocode = true
                let newRegion = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )

                withAnimation {
                    region = newRegion
                    cameraPosition = .region(newRegion)
                }
                locationText = formattedAddress(from: placemark)
                searchError = nil
            }
        }
    }

    private func regionCenterChanged(to newCenter: CLLocationCoordinate2D) {
        if shouldSkipNextReverseGeocode {
            shouldSkipNextReverseGeocode = false
            return
        }

        geocodeWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            reverseGeocode(for: newCenter)
        }

        geocodeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
    }

    private func reverseGeocode(for coordinate: CLLocationCoordinate2D) {
        geocoder.cancelGeocode()
        isGeocoding = true
        searchError = nil

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                isGeocoding = false
            }

            if let error = error as? CLError, error.code == .geocodeCanceled {
                return
            }

            DispatchQueue.main.async {
                if let placemark = placemarks?.first, error == nil {
                    locationText = formattedAddress(from: placemark)
                    searchError = nil
                } else {
                    searchError = "We couldn't determine an address here."
                    if locationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        locationText = fallbackAddress(for: coordinate)
                    }
                }
            }
        }
    }

    private func confirmSelection() {
        let coordinate = region.center
        var trimmed = locationText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            trimmed = fallbackAddress(for: coordinate)
        }
        locationText = trimmed
        onConfirm(coordinate)
        dismiss()
    }

    private func formattedAddress(from placemark: CLPlacemark) -> String {
        var parts: [String] = []

        if let number = placemark.subThoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines), !number.isEmpty {
            parts.append(number)
        }

        if let street = placemark.thoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines), !street.isEmpty {
            parts.append(street)
        }

        if parts.isEmpty, let name = placemark.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            let trimmedName = name.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? name
            if !trimmedName.isEmpty {
                parts.append(trimmedName)
            }
        }

        guard !parts.isEmpty else {
            return fallbackAddress(for: placemark.location?.coordinate ?? region.center)
        }

        if parts.count >= 2 {
            return "\(parts[0]), \(parts[1])"
        }

        return parts[0]
    }

    private func fallbackAddress(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "Lat %.5f, Lon %.5f", coordinate.latitude, coordinate.longitude)
    }
}
