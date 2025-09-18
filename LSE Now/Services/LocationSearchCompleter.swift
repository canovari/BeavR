import Foundation
import MapKit

class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    private var searchCompleter = MKLocalSearchCompleter()
    
    @Published var suggestions: [String] = []
    
    override init() {
        super.init()
        searchCompleter.delegate = self
        
        // Restrict search around LSE campus
        let lseRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.5145, longitude: -0.1160),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        searchCompleter.region = lseRegion
    }
    
    func update(query: String) {
        searchCompleter.queryFragment = query
    }
    
    func clear() {
        suggestions = []
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.suggestions = completer.results.map { $0.title }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Location search error: \(error.localizedDescription)")
    }
}
