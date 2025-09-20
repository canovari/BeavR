import SwiftUI
import MapKit
import Combine

struct MapView: View {
    @ObservedObject var vm: PostListViewModel
    @EnvironmentObject private var locationManager: LocationManager

    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5145, longitude: -0.1160), // LSE
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    @State private var cameraPosition = MapCameraPosition.region(MapView.defaultRegion)
    @State private var hasCenteredOnUser = false
    @State private var showLocationButton = false

    @State private var currentRegion: MKCoordinateRegion = defaultRegion
    @State private var shakeToggle = false
    @State private var timer: Timer?

    // Posts with valid coordinates, not expired
    private var postsWithCoords: [Post] {
        let now = Date()
        return vm.posts.filter { post in
            guard let _ = post.latitude, let _ = post.longitude else { return false }
            return !post.isExpired(referenceDate: now)
        }
    }

    private var sortedPosts: [Post] {
        postsWithCoords.sorted { $0.startTime < $1.startTime }
    }

    private var isLocationAuthorized: Bool {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    private var annotatedPosts: [(post: Post, coordinate: CLLocationCoordinate2D)] {
        sortedPosts.compactMap { post in
            coordinate(for: post).map { (post, $0) }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Map(position: $cameraPosition, interactionModes: .all) {
                if isLocationAuthorized {
                    UserAnnotation()
                }

                ForEach(annotatedPosts, id: \.post.id) { entry in
                    let post = entry.post
                    let coordinate = entry.coordinate
                    let now = Date()
                    let hasStarted = now >= post.startTime
                    let isUnder1Hour = !hasStarted && now.distance(to: post.startTime) < 3600
                    let timeText = timeLabel(for: post.startTime, endTime: post.endTime)
                    let zIndexValue = zIndexFor(post: post)

                    Annotation(post.title, coordinate: coordinate) {
                        PostAnnotationView(
                            post: post,
                            timeLabel: timeText,
                            isUnder1Hour: isUnder1Hour,
                            hasStarted: hasStarted,
                            shakeToggle: shakeToggle,
                            zIndexValue: zIndexValue
                        )
                    }
                    .annotationTitles(.hidden)
                }
            }
            .ignoresSafeArea()
            .onAppear {
                vm.fetchPosts()
                startTimer()
                locationManager.refreshLocation()
            }
            .onDisappear { stopTimer() }
            .onReceive(locationManager.$latestLocation.compactMap { $0 }) { location in
                if !hasCenteredOnUser {
                    let region = MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                    withAnimation {
                        cameraPosition = .region(region)
                    }
                    hasCenteredOnUser = true
                    showLocationButton = false
                }
            }
            .onChange(of: locationManager.authorizationStatus) { _, newStatus in
                if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                    locationManager.refreshLocation()
                }
            }
            .onMapCameraChange { context in
                let region = context.region
                currentRegion = region
                updateLocationButtonVisibility()
            }

            // Locate Me button
            if isLocationAuthorized {
                Button {
                    if let location = locationManager.latestLocation {
                        let region = MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                        withAnimation {
                            cameraPosition = .region(region)
                        }
                        withAnimation {
                            showLocationButton = false
                        }
                    }
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color("LSERed"))
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                .padding(.leading, 16)
                .padding(.bottom, 20)
                .opacity(showLocationButton ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: showLocationButton)
            }
        }
    }

    private func updateLocationButtonVisibility() {
        guard let userLocation = locationManager.latestLocation else { return }
        let visible = regionContains(region: currentRegion, coordinate: userLocation.coordinate)
        withAnimation {
            showLocationButton = !visible
        }
    }

    private func regionContains(region: MKCoordinateRegion, coordinate: CLLocationCoordinate2D) -> Bool {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        return (coordinate.latitude >= minLat && coordinate.latitude <= maxLat) &&
               (coordinate.longitude >= minLon && coordinate.longitude <= maxLon)
    }

    private func coordinate(for post: Post) -> CLLocationCoordinate2D? {
        guard let latitude = post.latitude, let longitude = post.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func zIndexFor(post: Post) -> Double {
        if let idx = sortedPosts.firstIndex(of: post) {
            return Double(sortedPosts.count - idx)
        }
        return 0
    }

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

private struct PostAnnotationView: View {
    let post: Post
    let timeLabel: String
    let isUnder1Hour: Bool
    let hasStarted: Bool
    let shakeToggle: Bool
    let zIndexValue: Double

    var body: some View {
        NavigationLink(value: post) {
            VStack(spacing: 4) {
                Text(post.category?.prefix(1) ?? "📍")
                    .font(.title2)
                Text(timeLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isUnder1Hour ? .red : .primary)
            }
            .padding(6)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(radius: 3)
            .opacity(hasStarted ? 0.6 : 1.0) // ✅ only dim started events
            .offset(x: isUnder1Hour && shakeToggle ? -6 : 6)
            .animation(
                isUnder1Hour
                ? .easeInOut(duration: 0.08).repeatCount(5, autoreverses: true)
                : .default,
                value: shakeToggle
            )
        }
        .buttonStyle(.plain)
        .zIndex(zIndexValue)
    }
}


private extension Date {
    func distance(to other: Date) -> TimeInterval {
        other.timeIntervalSince(self)
    }
}
