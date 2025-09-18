import SwiftUI
import MapKit

struct ConfirmEventSpotView: View {
    @State private var region: MKCoordinateRegion
    @State private var hasConfirmed = false
    let initialCoordinate: CLLocationCoordinate2D?
    let onConfirm: (CLLocationCoordinate2D) -> Void
    
    @Environment(\.dismiss) var dismiss
    
    init(initialCoordinate: CLLocationCoordinate2D? = nil,
         onConfirm: @escaping (CLLocationCoordinate2D) -> Void) {
        self.initialCoordinate = initialCoordinate
        self.onConfirm = onConfirm
        
        // If we already have a coordinate, start from it
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
            Text(hasConfirmed ? "Selected Location" : "Select Event Location")
                .font(.headline)
            
            ZStack {
                Map(coordinateRegion: $region)
                    .frame(height: 400)
                    .cornerRadius(12)
                    .shadow(radius: 3)
                
                // Apple-like red dot
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 2)
                    )
            }
            
            Button {
                hasConfirmed = true
                onConfirm(region.center)
                dismiss() // 👈 close the sheet and go back
            } label: {
                Text(hasConfirmed ? "Change Pin" : "Confirm")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("LSERed"))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}
