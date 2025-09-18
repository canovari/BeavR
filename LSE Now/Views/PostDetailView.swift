import SwiftUI
import MapKit
import UIKit

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
                    organizationView(name: org, contact: post.contact)
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
                    descriptionView(for: desc)
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

    @ViewBuilder
    private func organizationView(name: String, contact: ContactInfo?) -> some View {
        if let contact {
            Button {
                handleContact(contact)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: contactIcon(for: contact.type))
                        .foregroundColor(Color("LSERed"))
                    Text("by \(name)")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .underline()
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        } else {
            Text("by \(name)")
                .font(.headline)
                .foregroundColor(.primary)
        }
    }

    @ViewBuilder
    private func descriptionView(for text: String) -> some View {
        Text(attributedDescription(from: text))
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func attributedDescription(from text: String) -> AttributedString {
        let attributed = NSMutableAttributedString(string: text)

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(location: 0, length: attributed.length)
            detector.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard let match, let url = match.url else { return }
                attributed.addAttribute(.link, value: url, range: match.range)
                attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
                attributed.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: match.range)
            }
        }

        return AttributedString(attributed)
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
