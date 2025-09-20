import SwiftUI
import MapKit

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
    @State private var usePinStyle = false
    @State private var selectedPost: Post?

    private let pinZoomThreshold: CLLocationDegrees = 0.02

    // Posts with valid coordinates, not expired, and within the next six days
    private var postsWithCoords: [Post] {
        let now = Date()
        let sixDaysAhead = Calendar.current.date(byAdding: .day, value: 6, to: now) ?? now

        return vm.posts.filter { post in
            guard let _ = post.latitude, let _ = post.longitude else { return false }
            guard !post.isExpired(referenceDate: now) else { return false }
            return post.startTime <= sixDaysAhead
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
        NavigationStack {
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
                        let isSameDay = Calendar.current.isDateInToday(post.startTime)
                        Annotation(post.title, coordinate: coordinate) {
                            Button {
                                selectedPost = post
                            } label: {
                                EventMarkerView(
                                    style: usePinStyle ? .pin : .card,
                                    post: post,
                                    timeLabel: timeText,
                                    isUnder1Hour: isUnder1Hour,
                                    hasStarted: hasStarted,
                                    isSameDay: isSameDay,
                                    shakeToggle: shakeToggle
                                )
                            }
                            .buttonStyle(.plain)
                            .zIndex(zIndexValue)
                        }
                        .annotationTitles(.hidden)
                    }
                }
                .ignoresSafeArea(edges: [.horizontal, .bottom])
                .onAppear {
                    vm.fetchPosts()
                    startTimer()
                    locationManager.refreshLocation()
                    usePinStyle = shouldUsePinStyle(for: currentRegion)
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

                    let newPinStyle = shouldUsePinStyle(for: region)
                    if newPinStyle != usePinStyle {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            usePinStyle = newPinStyle
                        }
                    }

                    updateLocationButtonVisibility()
                }

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
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedPost) { post in
                PostDetailView(post: post)
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

    private func shouldUsePinStyle(for region: MKCoordinateRegion) -> Bool {
        region.span.latitudeDelta > pinZoomThreshold ||
        region.span.longitudeDelta > pinZoomThreshold
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
            return start.formatted(.dateTime.weekday(.wide))
        }
    }
}

private struct EventMarkerView: View {
    enum Style {
        case pin
        case card
    }

    let style: Style
    let post: Post
    let timeLabel: String
    let isUnder1Hour: Bool
    let hasStarted: Bool
    let isSameDay: Bool
    let shakeToggle: Bool

    private let pinDiameter: CGFloat = 34

    var body: some View {
        content
            .background(background)
            .overlay(borderOverlay)
            .clipShape(MorphingMarkerShape(cornerRadius: cornerRadius))
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowYOffset)
            .opacity(hasStarted ? 0.6 : 1.0)
            .offset(x: horizontalOffset)
            .animation(.easeInOut(duration: 0.25), value: style)
            .animation(shakeAnimation, value: shakeToggle)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .pin:
            Text(post.category?.prefix(1) ?? "📍")
                .font(.system(size: 20))
                .frame(width: pinDiameter, height: pinDiameter)
                .foregroundColor(pinTextColor)
        case .card:
            VStack(spacing: timeLabel.isEmpty ? 0 : 4) {
                Text(post.category?.prefix(1) ?? "📍")
                    .font(.title2)
                    .foregroundColor(cardTextColor)
                if !timeLabel.isEmpty {
                    Text(timeLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(cardTimeColor)
                }
            }
            .padding(6)
        }
    }

    @ViewBuilder
    private var background: some View {
        if style == .pin {
            MorphingMarkerShape(cornerRadius: cornerRadius)
                .fill(pinGradient)
        } else {
            MorphingMarkerShape(cornerRadius: cornerRadius)
                .fill(cardBackgroundColor)
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if style == .pin {
            MorphingMarkerShape(cornerRadius: cornerRadius)
                .stroke(pinStrokeColor, lineWidth: 2)
        }
    }

    private var horizontalOffset: CGFloat {
        guard style == .card, isUnder1Hour else { return 0 }
        return shakeToggle ? -6 : 6
    }

    private var shakeAnimation: Animation {
        guard style == .card, isUnder1Hour else { return .default }
        return .easeInOut(duration: 0.08).repeatCount(5, autoreverses: true)
    }

    private var cornerRadius: CGFloat {
        style == .pin ? pinDiameter / 2 : 10
    }

    private var pinColor: Color {
        isSameDay ? Color("LSERed") : .white
    }

    private var pinGradient: LinearGradient {
        if isSameDay {
            return LinearGradient(
                colors: [pinColor, pinColor.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [.white, Color.white.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var pinStrokeColor: Color {
        isSameDay ? Color.white.opacity(0.35) : Color("LSERed").opacity(0.45)
    }

    private var pinTextColor: Color {
        isSameDay ? .white : Color("LSERed")
    }

    private var cardBackgroundColor: Color {
        isSameDay ? Color("LSERed") : Color(.systemBackground).opacity(0.95)
    }

    private var cardTextColor: Color {
        isSameDay ? .white : .primary
    }

    private var cardTimeColor: Color {
        if isSameDay { return .white }
        return isUnder1Hour ? .red : .primary
    }

    private var shadowColor: Color {
        switch style {
        case .pin:
            return isSameDay ? pinColor.opacity(0.35) : Color.black.opacity(0.15)
        case .card:
            return Color.black.opacity(0.18)
        }
    }

    private var shadowRadius: CGFloat {
        style == .pin ? 4 : 3
    }

    private var shadowYOffset: CGFloat {
        style == .pin ? 2 : 0
    }
}

private struct MorphingMarkerShape: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, min(rect.width, rect.height) / 2)
        return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
    }

    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }
}
private extension Date {
    func distance(to other: Date) -> TimeInterval {
        other.timeIntervalSince(self)
    }
}
