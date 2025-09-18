import SwiftUI
import MapKit
import CoreLocation

struct ConfirmEventSpotView: View {
    @Binding var locationText: String
    @State private var region: MKCoordinateRegion
    @State private var searchError: String?
    @State private var geocodeWorkItem: DispatchWorkItem?
    @State private var shouldSkipNextReverseGeocode = false
    @State private var isGeocoding = false
    @FocusState private var isAddressFieldFocused: Bool

    private let geocoder = CLGeocoder()
    let initialCoordinate: CLLocationCoordinate2D?
    let onConfirm: (CLLocationCoordinate2D) -> Void

    @Environment(\.dismiss) var dismiss

    init(initialCoordinate: CLLocationCoordinate2D? = nil,
         locationText: Binding<String>,
         onConfirm: @escaping (CLLocationCoordinate2D) -> Void) {
        self.initialCoordinate = initialCoordinate
        self.onConfirm = onConfirm
        self._locationText = locationText

        if let coord = initialCoordinate {
            _region = State(initialValue: MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
        } else {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 51.5145, longitude: -0.1160),
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Select Event Location")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Search for an address or drag the map to drop the pin.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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

            if let searchError {
                Text(searchError)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ZStack {
                Map(coordinateRegion: regionBinding)
                    .frame(height: 360)
                    .cornerRadius(12)
                    .shadow(radius: 3)

                Circle()
                    .fill(Color("LSERed"))
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 2)
                    )
                    .shadow(radius: 1)
            }

            if !locationText.isEmpty {
                Text(locationText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

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
        .padding()
        .navigationTitle("Map Pin")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let coord = initialCoordinate, locationText.isEmpty {
                reverseGeocode(for: coord)
            }
        }
        .onDisappear {
            geocodeWorkItem?.cancel()
            geocoder.cancelGeocode()
        }
    }

    private var regionBinding: Binding<MKCoordinateRegion> {
        Binding(
            get: { region },
            set: { newRegion in
                let previousCenter = region.center
                region = newRegion
                guard coordinatesChanged(from: previousCenter, to: newRegion.center) else {
                    return
                }
                regionCenterChanged(to: newRegion.center)
            }
        )
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
                withAnimation {
                    region = MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    )
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
        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")

        let locality = [placemark.locality, placemark.administrativeArea, placemark.postalCode]
            .compactMap { $0 }
            .joined(separator: ", ")

        let country = placemark.country

        let components = [street.isEmpty ? placemark.name : street, locality, country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        if components.isEmpty {
            return fallbackAddress(for: placemark.location?.coordinate ?? region.center)
        }

        return components.joined(separator: ", ")
    }

    private func fallbackAddress(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "Lat %.5f, Lon %.5f", coordinate.latitude, coordinate.longitude)
    }
}

private func coordinatesChanged(from oldCenter: CLLocationCoordinate2D, to newCenter: CLLocationCoordinate2D) -> Bool {
    let threshold = 1e-6
    return abs(oldCenter.latitude - newCenter.latitude) > threshold ||
        abs(oldCenter.longitude - newCenter.longitude) > threshold
}
