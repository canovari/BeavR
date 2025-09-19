import SwiftUI
import MapKit

struct MapView: View {
    @ObservedObject var vm: PostListViewModel
    @EnvironmentObject private var locationManager: LocationManager

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5145, longitude: -0.1160), // LSE
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    @State private var shakeToggle = false
    @State private var timer: Timer?
    @State private var hasCenteredOnUser = false

    // Only posts with coordinates + not ended + within 16h
    private var postsWithCoords: [Post] {
        let now = Date()
        let cutoff = now.addingTimeInterval(16 * 3600) // 16 hours ahead

        return vm.posts.filter { post in
            guard let _ = post.latitude, let _ = post.longitude else { return false }

            // hide if expired based on end time or start time window
            if post.isExpired(referenceDate: now) { return false }

            // show only if start time within next 16h
            return post.startTime <= cutoff
        }
    }

    // Sorted chronologically (earliest → latest)
    private var sortedPosts: [Post] {
        postsWithCoords.sorted { $0.startTime < $1.startTime }
    }

    private var mapItems: [MapAnnotationItem] {
        var annotations = sortedPosts.compactMap { post -> MapAnnotationItem? in
            guard let latitude = post.latitude, let longitude = post.longitude else { return nil }
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            return MapAnnotationItem(id: "post-\(post.id)", coordinate: coordinate, kind: .event(post))
        }

        if let userCoordinate = locationManager.coordinate {
            annotations.append(
                MapAnnotationItem(id: "user-location", coordinate: userCoordinate, kind: .userLocation)
            )
        }

        return annotations
    }

    var body: some View {
        NavigationStack {
            Map(coordinateRegion: $region, annotationItems: mapItems) { item in
                switch item.kind {
                case .event(let post):
                    return MapAnnotation(coordinate: item.coordinate) {
                        eventAnnotation(for: post)
                    }
                case .userLocation:
                    return MapAnnotation(coordinate: item.coordinate) {
                        UserLocationAnnotationView()
                    }
                }
            }
            .edgesIgnoringSafeArea(.top)
            .onAppear {
                vm.fetchPosts()
                startTimer()
            }
            .onDisappear { stopTimer() }
            .onReceive(locationManager.$location) { location in
                guard !hasCenteredOnUser, let coordinate = location?.coordinate else { return }
                region.center = coordinate
                hasCenteredOnUser = true
            }
            .navigationDestination(for: Post.self) { post in
                PostDetailView(post: post)
            }
        }
    }

    private func eventAnnotation(for post: Post) -> some View {
        let hasStarted = Date() >= post.startTime
        let isUnder1Hour = !hasStarted && Date().distance(to: post.startTime) < 3600

        return NavigationLink(value: post) {
            VStack(spacing: 4) {
                Text(post.category?.prefix(1) ?? "📍")
                    .font(.title2)

                Text(timeLabel(for: post.startTime, endTime: post.endTime))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isUnder1Hour ? .red : .primary)
            }
            .padding(6)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(radius: 3)
            .opacity(hasStarted ? 0.6 : 1.0)
            .offset(x: isUnder1Hour && shakeToggle ? -6 : 6)
            .animation(
                isUnder1Hour
                ? .easeInOut(duration: 0.08).repeatCount(5, autoreverses: true)
                : .default,
                value: shakeToggle
            )
        }
        .buttonStyle(.plain)
    }

    // Timer for jiggle
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { _ in
            withAnimation { shakeToggle.toggle() }
        }
    }
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // Time label formatter
    private func timeLabel(for start: Date, endTime: Date?) -> String {
        let now = Date()
        if let end = endTime, now > end { return "" }

        let diff = start.timeIntervalSinceNow
        if diff < 0 {
            return "Started"
        } else if diff < 3600 {
            return "in \(Int(diff / 60))m"
        } else if Calendar.current.isDateInToday(start) || diff < 6 * 3600 {
            return start.formatted(date: .omitted, time: .shortened)
        } else if Calendar.current.isDateInTomorrow(start) {
            return "Tomorrow"
        } else {
            return start.formatted(.dateTime.weekday(.abbreviated))
        }
    }
}

private extension Date {
    func distance(to other: Date) -> TimeInterval {
        other.timeIntervalSince(self)
    }
}

private struct MapAnnotationItem: Identifiable {
    enum Kind {
        case event(Post)
        case userLocation
    }

    let id: String
    let coordinate: CLLocationCoordinate2D
    let kind: Kind
}

private struct UserLocationAnnotationView: View {
    @State private var animatePulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.2))
                .frame(width: 56, height: 56)
                .scaleEffect(animatePulse ? 1.3 : 0.5)
                .opacity(animatePulse ? 0 : 0.6)

            Circle()
                .fill(Color.red)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
        }
        .onAppear {
            animatePulse = true
        }
        .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: animatePulse)
    }
}
