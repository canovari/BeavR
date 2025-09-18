import SwiftUI
import MapKit

struct PostDetailView: View {
    let post: Post

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // --- Title
                Text(post.title)
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.leading)

                // --- Date & Time
                if let end = post.endTime {
                    Label("\(post.startTime.formatted(date: .abbreviated, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))",
                          systemImage: "calendar")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    Label(post.startTime.formatted(date: .abbreviated, time: .shortened),
                          systemImage: "calendar")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }

                // --- Location text
                if let place = post.location, !place.isEmpty {
                    Label(place, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // --- Organization
                if let org = post.organization, !org.isEmpty {
                    Text("by \(org)")
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                // --- Contact
                if let contact = post.contact {
                    Button {
                        handleContact(contact)
                    } label: {
                        HStack {
                            Image(systemName: contactIcon(for: contact.type))
                                .foregroundColor(Color("LSERed"))
                            Text("\(contact.type): \(contact.value)")
                                .foregroundColor(.blue)
                                .underline()
                        }
                    }
                }

                Divider()

                // --- Category
                if let category = post.category {
                    Label(category, systemImage: "tag")
                        .font(.headline)
                        .foregroundColor(Color("LSERed"))
                }

                // --- Description (plain text)
                if let desc = post.description, !desc.isEmpty {
                    Text(desc)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // --- Get Directions (moved here)
                if let lat = post.latitude, let lon = post.longitude {
                    Button(action: {
                        openInMaps(latitude: lat, longitude: lon, name: post.title)
                    }) {
                        Text("Get Directions")
                            .font(.subheadline)
                            .foregroundColor(Color("LSERed"))
                    }
                }

                // --- Map Preview
                if let lat = post.latitude, let lon = post.longitude {
                    Map(coordinateRegion: .constant(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    )), annotationItems: [CLLocationCoordinate2D(latitude: lat, longitude: lon)]) { coord in
                        MapMarker(coordinate: coord, tint: .red)
                    }
                    .frame(height: 200)
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground)) // ✅ same as Explore/New Event
        .navigationTitle("Event Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Open Apple Maps
    private func openInMaps(latitude: Double, longitude: Double, name: String) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

    // MARK: - Contact Handling
    private func handleContact(_ contact: ContactInfo) {
        switch contact.type.lowercased() {
        case "phone":
            if let url = URL(string: "tel://\(contact.value)") {
                UIApplication.shared.open(url)
            }
        case "whatsapp":
            if let url = URL(string: "https://wa.me/\(contact.value)") {
                UIApplication.shared.open(url)
            }
        case "instagram":
            if let url = URL(string: "https://instagram.com/\(contact.value)") {
                UIApplication.shared.open(url)
            }
        case "facebook":
            if let url = URL(string: "https://facebook.com/\(contact.value)") {
                UIApplication.shared.open(url)
            }
        case "email":
            if let url = URL(string: "mailto:\(contact.value)") {
                UIApplication.shared.open(url)
            }
        default:
            if let url = URL(string: contact.value) {
                UIApplication.shared.open(url)
            }
        }
    }

    private func contactIcon(for type: String) -> String {
        switch type.lowercased() {
        case "phone": return "phone.fill"
        case "whatsapp": return "message.fill"
        case "instagram": return "camera.fill"
        case "facebook": return "f.circle.fill"
        case "email": return "envelope.fill"
        default: return "person.crop.circle"
        }
    }

}

// MARK: - Identifiable helper
extension CLLocationCoordinate2D: Identifiable {
    public var id: String { "\(latitude),\(longitude)" }
}
