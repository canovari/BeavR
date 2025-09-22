import SwiftUI
import MapKit
import UIKit
import Combine

struct PostDetailView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    @ObservedObject private var viewModel: PostListViewModel
    @State private var currentPost: Post
    @State private var showLoginAlert = false

    init(post: Post, viewModel: PostListViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _currentPost = State(initialValue: post)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                Label {
                    Text(currentPost.conciseScheduleString())
                } icon: {
                    Image(systemName: "calendar")
                }
                .foregroundColor(.secondary)
                .font(.subheadline)

                if let place = currentPost.primaryLocationLine ?? currentPost.location, !place.isEmpty {
                    Label(place, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if let org = currentPost.organization, !org.isEmpty {
                    organizationView(name: org, contact: currentPost.contact)
                }

                Divider()

                if let category = currentPost.category {
                    Text(category)
                        .font(.headline)
                        .foregroundColor(Color("LSERed"))
                }

                if let desc = currentPost.description, !desc.isEmpty {
                    descriptionView(for: desc)
                }

                if let lat = currentPost.latitude, let lon = currentPost.longitude {
                    Button(action: {
                        openInMaps(latitude: lat, longitude: lon, name: currentPost.title)
                    }) {
                        Text("Get Directions")
                            .font(.subheadline)
                            .foregroundColor(Color("LSERed"))
                    }
                }

                if let lat = currentPost.latitude, let lon = currentPost.longitude {
                    mapPreview(latitude: lat, longitude: lon)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Event Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .alert("Log In Required", isPresented: $showLoginAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Log in with your LSE account to save events.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventLikeStatusDidChange)) { notification in
            guard let change = EventLikeChange.from(notification), change.eventID == currentPost.id else { return }
            if let updated = change.post {
                currentPost = updated
            } else {
                currentPost = currentPost.updatingLikeState(
                    likesCount: change.likeCount,
                    likedByMe: change.isLiked
                )
            }
        }
        .onReceive(viewModel.$posts) { _ in
            if let updatedPost = viewModel.post(withID: currentPost.id) {
                currentPost = updatedPost
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(currentPost.title)
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.leading)

            Spacer(minLength: 12)

            EventLikeButton(
                isLiked: currentPost.likedByMe,
                likeCount: currentPost.likesCount,
                isLoading: isUpdatingLike,
                action: toggleLike,
                iconSize: 22
            )
            .alignmentGuide(.firstTextBaseline) { context in
                context[VerticalAlignment.center]
            }
        }
    }

    private var isUpdatingLike: Bool {
        viewModel.isUpdatingLike(for: currentPost.id)
    }

    private func toggleLike() {
        guard let token = authViewModel.token else {
            showLoginAlert = true
            return
        }

        let originalPost = currentPost
        let targetIsLiked = !originalPost.likedByMe
        let delta = targetIsLiked ? 1 : -1
        let updatedCount = max(0, originalPost.likesCount + delta)

        withAnimation(.easeInOut(duration: 0.2)) {
            currentPost = originalPost.updatingLikeState(
                likesCount: updatedCount,
                likedByMe: targetIsLiked
            )
        }

        Task {
            await viewModel.toggleLike(for: originalPost, token: token)
            await MainActor.run {
                if let message = viewModel.likeErrorMessage, !message.isEmpty {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentPost = originalPost
                    }
                }
            }
        }
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

    private func mapPreview(latitude: Double, longitude: Double) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )

        return Group {
            if #available(iOS 17.0, *) {
                Map(position: .constant(.region(region))) {
                    Marker(currentPost.title, coordinate: coordinate)
                }
            } else {
                Map(
                    coordinateRegion: .constant(region),
                    annotationItems: [MapAnnotationItem(coordinate: coordinate)]
                ) { item in
                    MapAnnotation(coordinate: item.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(Color("LSERed"))
                            .font(.title2)
                    }
                }
            }
        }
        .frame(height: 200)
        .cornerRadius(12)
    }

    private func openInMaps(latitude: Double, longitude: Double, name: String) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

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
            if let url = instagramURL(from: contact.value) {
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

    private func instagramURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
            return url
        }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("instagram.com") || lower.hasPrefix("www.instagram.com") ||
            lower.hasPrefix("instagr.am") || lower.hasPrefix("www.instagr.am") {
            return URL(string: "https://\(trimmed)")
        }

        let handle = ContactInfo.sanitizedValue(for: "instagram", rawValue: trimmed)
        guard !handle.isEmpty else { return nil }
        return URL(string: "https://instagram.com/\(handle)")
    }
}

private struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
