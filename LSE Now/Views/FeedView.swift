import SwiftUI
import CoreLocation

enum FeedSortOption: String, CaseIterable, Identifiable {
    case time
    case location

    var id: String { rawValue }

    var title: String {
        switch self {
        case .time:
            return "Time"
        case .location:
            return "Location"
        }
    }
}

struct FeedView: View {
    @ObservedObject var vm: PostListViewModel
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var showFilterSheet = false
    @State private var selectedCategories: Set<String> = Set(FilterSheet.categories)
    @State private var selectedDate: Date? = nil
    @State private var searchText: String = ""
    @State private var sortOption: FeedSortOption = .time
    @State private var radiusMiles: Double = 5

    // Single animation driver for all live indicators
    @State private var blink = false
    @State private var activeAlert: FeedAlert?

    private var isLocationAccessAuthorized: Bool {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    var filteredPosts: [Post] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let knownCategories = Set(FilterSheet.categories)
        let isFilteringCategories = !selectedCategories.isEmpty && selectedCategories.count < knownCategories.count

        let posts = vm.posts.filter { post in
            if isFilteringCategories {
                guard let category = post.category else { return false }

                if knownCategories.contains(category) {
                    guard selectedCategories.contains(category) else { return false }
                }
            } else if selectedCategories.isEmpty {
                return false
            }

            if let date = selectedDate, !Calendar.current.isDate(post.startTime, inSameDayAs: date) {
                return false
            }

            guard trimmedSearch.isEmpty else {
                let keyword = trimmedSearch.lowercased()
                let titleMatch = post.title.lowercased().contains(keyword)
                let organizerMatch = post.organization?.lowercased().contains(keyword) ?? false

                return titleMatch || organizerMatch
            }

            return true
        }

        switch sortOption {
        case .time:
            return posts.sorted { $0.startTime < $1.startTime }
        case .location:
            guard let userLocation = locationManager.latestLocation else {
                return posts.sorted { $0.startTime < $1.startTime }
            }

            let radiusInMeters = radiusMiles * 1609.34

            let postsWithDistance = posts.compactMap { post -> (post: Post, distance: CLLocationDistance)? in
                guard let latitude = post.latitude, let longitude = post.longitude else { return nil }
                let coordinate = CLLocation(latitude: latitude, longitude: longitude)
                let distance = userLocation.distance(from: coordinate)
                guard distance <= radiusInMeters else { return nil }
                return (post, distance)
            }

            return postsWithDistance
                .sorted { $0.distance < $1.distance }
                .map(\.post)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        if sortOption == .location && !isLocationAccessAuthorized {
                            LocationSortUnavailableView()
                        }

                        if sortOption == .location && locationManager.latestLocation != nil && filteredPosts.isEmpty {
                            Text("No events within \(Int(radiusMiles)) miles of you.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 12)
                        }

                        ForEach(filteredPosts) { post in
                            NavigationLink(destination: PostDetailView(post: post, viewModel: vm)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(categoryEmoji(for: post.category)) \(post.title)")
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    if let org = post.organization, !org.isEmpty {
                                        Text("by \(org)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    HStack(alignment: .firstTextBaseline) {
                                        dateOrLiveView(for: post)
                                            .font(.subheadline)

                                        Spacer(minLength: 12)

                                        EventLikeButton(
                                            isLiked: post.likedByMe,
                                            likeCount: post.likesCount,
                                            isLoading: vm.isUpdatingLike(for: post.id),
                                            action: { handleLike(for: post) }
                                        )
                                        .alignmentGuide(.firstTextBaseline) { context in
                                            context[VerticalAlignment.center]
                                        }
                                    }
                                    .padding(.top, 8)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(radius: 1)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await refreshFeed()
                }

                if vm.posts.isEmpty && vm.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
            .navigationTitle("Feed")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search events")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheet(
                    selectedCategories: $selectedCategories,
                    selectedDate: $selectedDate,
                    sortOption: $sortOption,
                    radiusMiles: $radiusMiles
                )
            }
            .alert(item: $activeAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK")) {
                        if case .likeError = alert {
                            vm.clearLikeError()
                        }
                    }
                )
            }
            .onAppear {
                // Start blinking loop
                blink = true
            }
            .onDisappear {
                blink = false
            }
            .onChange(of: sortOption) { _, newValue in
                if newValue == .location {
                    locationManager.refreshLocation()
                }
            }
            .onChange(of: vm.likeErrorMessage) { _, message in
                guard let message else { return }
                activeAlert = .likeError(id: UUID(), message: message)
            }
        }
    }

    private func refreshFeed() async {
        let minimumDuration: TimeInterval = 1
        let start = Date()
        await vm.refreshPosts()

        guard !Task.isCancelled else { return }

        let elapsed = Date().timeIntervalSince(start)
        let remaining = minimumDuration - elapsed
        guard remaining > 0 else { return }

        let delay = UInt64((remaining * 1_000_000_000).rounded())
        try? await Task.sleep(nanoseconds: delay)
    }

    // MARK: - Helpers
    private func handleLike(for post: Post) {
        guard let token = authViewModel.token else {
            activeAlert = .login(id: UUID())
            return
        }

        Task {
            await vm.toggleLike(for: post, token: token)
        }
    }

    private func eventIsOngoing(post: Post) -> Bool {
        let now = Date()
        guard now >= post.startTime else { return false }
        return !post.isExpired(referenceDate: now)
    }

    @ViewBuilder
    private func dateOrLiveView(for post: Post) -> some View {
        if eventIsOngoing(post: post) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color("LSERed").opacity(0.45))
                        .frame(width: 16, height: 16)
                        .scaleEffect(blink ? 1.45 : 0.95)
                        .opacity(blink ? 0.35 : 0.85)

                    Circle()
                        .fill(Color("LSERed"))
                        .frame(width: 8, height: 8)
                        .shadow(color: Color("LSERed").opacity(0.5), radius: 2)
                }
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: blink)

                Text(liveStatusText(for: post))
                    .foregroundColor(Color("LSERed"))
            }
        } else {
            Text(formattedDate(for: post.startTime))
                .foregroundColor(Color("LSERed"))
        }
    }

    private func liveStatusText(for post: Post) -> String {
        let minutes = Int(Date().timeIntervalSince(post.startTime) / 60)
        if minutes < 1 {
            return "Started just now"
        }
        return "Started \(minutes)m ago"
    }
    
    private func formattedDate(for date: Date) -> String {
        let cal = Calendar.current
        let now = Date()
        
        if cal.isDate(date, inSameDayAs: now) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if cal.isDate(date, inSameDayAs: cal.date(byAdding: .day, value: 1, to: now)!) {
            return "Tomorrow"
        } else if let diff = cal.dateComponents([.day], from: now, to: date).day, diff < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        } else {
            return date.formatted(.dateTime.month().day())
        }
    }
    
    private func categoryEmoji(for category: String?) -> String {
        guard let cat = category, let first = cat.first else {
            return "📍"
        }
        return String(first)
    }

    private enum FeedAlert: Identifiable {
        case login(id: UUID)
        case likeError(id: UUID, message: String)

        var id: UUID {
            switch self {
            case .login(let id), .likeError(let id, _):
                return id
            }
        }

        var title: String {
            switch self {
            case .login:
                return "Log In Required"
            case .likeError:
                return "Unable to Save Event"
            }
        }

        var message: String {
            switch self {
            case .login:
                return "Sign in with your LSE email to like events."
            case .likeError(_, let message):
                return message
            }
        }
    }
}

private struct LocationSortUnavailableView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "location.slash")
                .font(.title3)
                .foregroundColor(Color("LSERed"))

            VStack(alignment: .leading, spacing: 4) {
                Text("Enable location access to sort by distance.")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("Until then, events are ordered by start time.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Filter Sheet
struct FilterSheet: View {
    @Binding var selectedCategories: Set<String>
    @Binding var selectedDate: Date?
    @Binding var sortOption: FeedSortOption
    @Binding var radiusMiles: Double

    @Environment(\.dismiss) var dismiss

    @EnvironmentObject private var locationManager: LocationManager

    private var isLocationAccessAuthorized: Bool {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    static let categories = [
        "Art Events 🎨", "Career 💼", "Club Events 🎉", "Cooking 👨‍🍳",
        "Cultural 🌍", "Festivals 🎊", "Freebie 😎", "Holiday ✨",
        "Ice Skating ⛸️", "Lectures 🎤", "Library 📚", "Movie 🎬", "Night Life 🎶",
        "Pride 🏳️‍🌈", "Shows 🎵", "Sports 🏀", "Trivia 🎲", "Wellness 🧘"
    ]

    private let radiusRange: ClosedRange<Double> = 1...20

    var body: some View {
        NavigationStack {
            Form {
                Section("Sort") {
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(FeedSortOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    if sortOption == .location {
                        if !isLocationAccessAuthorized {
                            Label("Location access required for distance sorting.", systemImage: "location.slash")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Radius")
                                Spacer()
                                Text("\(Int(radiusMiles)) mi")
                                    .foregroundColor(.secondary)
                            }

                            Slider(value: $radiusMiles, in: radiusRange, step: 1)

                            Text("Only events within this distance are shown when sorting by location.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                        .disabled(!isLocationAccessAuthorized)
                    }
                }

                Section("Categories") {
                    NavigationLink {
                        CategoryFilterListView(
                            selectedCategories: $selectedCategories,
                            categories: sortedCategories
                        )
                    } label: {
                        HStack {
                            Text("Selected")
                            Spacer()
                            Text(categorySummary)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Date") {
                    DatePicker("Select Date", selection: Binding(
                        get: { selectedDate ?? Date() },
                        set: { selectedDate = $0 }
                    ), displayedComponents: .date)
                    
                    if selectedDate != nil {
                        Button("Clear Date Filter") {
                            selectedDate = nil
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var categorySummary: String {
        if selectedCategories.isEmpty { return "None" }
        if selectedCategories.count == FilterSheet.categories.count { return "All" }

        let sorted = selectedCategories.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if sorted.count <= 3 {
            return sorted.joined(separator: ", ")
        }
        return "\(sorted.count) selected"
    }

    private var sortedCategories: [String] {
        FilterSheet.categories.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

private struct CategoryFilterListView: View {
    @Binding var selectedCategories: Set<String>
    let categories: [String]

    var body: some View {
        List {
            Section {
                Button("All") {
                    selectedCategories = Set(categories)
                }
            }

            ForEach(categories, id: \.self) { category in
                Button {
                    toggle(category)
                } label: {
                    HStack {
                        Text(category)
                        Spacer()
                        if selectedCategories.contains(category) {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color("LSERed"))
                        }
                    }
                }
                .foregroundColor(.primary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("All") {
                    selectedCategories = Set(categories)
                }
            }
        }
    }

    private func toggle(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }
}
