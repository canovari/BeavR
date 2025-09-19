import SwiftUI
import MapKit

struct MapView: View {
    @ObservedObject var vm: PostListViewModel

    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.5145, longitude: -0.1160), // LSE
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )

    @State private var shakeToggle = false
    @State private var timer: Timer?

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

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                ForEach(sortedPosts) { post in
                    if let coordinate = coordinate(for: post) {
                        Annotation(post.title, coordinate: coordinate) {
                            annotationView(for: post)
                        }
                    }
                }
            }
            .edgesIgnoringSafeArea(.top)
            .onAppear {
                vm.fetchPosts()
                startTimer()
            }
            .onDisappear { stopTimer() }
            .navigationDestination(for: Post.self) { post in
                PostDetailView(post: post)
            }
        }
    }

    private func coordinate(for post: Post) -> CLLocationCoordinate2D? {
        guard let latitude = post.latitude, let longitude = post.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func annotationView(for post: Post) -> some View {
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
        .zIndex(zIndexFor(post: post)) // earliest events on top
    }

    // Higher zIndex for earlier events
    private func zIndexFor(post: Post) -> Double {
        if let idx = sortedPosts.firstIndex(of: post) {
            return Double(sortedPosts.count - idx)
        }
        return 0
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
