import Foundation
import MapKit

struct LocationSuggestion: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String

    init(completion: MKLocalSearchCompletion) {
        self.title = completion.title
        self.subtitle = completion.subtitle
        self.id = "\(completion.title)|\(completion.subtitle)"
    }

    var displayText: String {
        if title.isEmpty { return subtitle }
        if subtitle.isEmpty { return title }
        return "\(title), \(subtitle)"
    }
}

class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    private let searchCompleter = MKLocalSearchCompleter()
    private let minimumSpanDelta: CLLocationDegrees = 0.02

    @Published var suggestions: [LocationSuggestion] = []

    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest, .query]

        // Restrict search around LSE campus
        let lseRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.5145, longitude: -0.1160),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        searchCompleter.region = normalizedRegion(lseRegion)
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            clear()
            return
        }

        searchCompleter.queryFragment = trimmed
    }

    func updateRegion(_ region: MKCoordinateRegion) {
        searchCompleter.region = normalizedRegion(region)
    }

    func clear() {
        suggestions = []
    }

    private func normalizedRegion(_ region: MKCoordinateRegion) -> MKCoordinateRegion {
        let span = region.span
        let latitudeDelta = max(span.latitudeDelta, minimumSpanDelta)
        let longitudeDelta = max(span.longitudeDelta, minimumSpanDelta)

        return MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
            .filter { !$0.title.isEmpty || !$0.subtitle.isEmpty }
            .prefix(5)
            .map(LocationSuggestion.init)

        DispatchQueue.main.async {
            self.suggestions = results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            print("Location search error: \(error.localizedDescription)")
        }
    }
}
