import SwiftUI

struct NewEventView: View {
    var body: some View {
        NavigationStack {   // ✅ wrap everything
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Title (same style as Explore / Feed)
                    Text("New Event")
                        .font(.largeTitle)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 44)

                    // Main buttons
                    VStack(spacing: 16) {
                        NavigationLink {
                            AddEventView()
                        } label: {
                            HubRectButton(icon: "plus.circle.fill", title: "Add Event")
                        }

                        NavigationLink {
                            AddDealView()
                        } label: {
                            HubRectButton(icon: "tag.fill", title: "Add Deal")
                        }

                        NavigationLink {
                            MyEventsView(mode: .likedOnly)
                        } label: {
                            HubRectButton(icon: "heart.fill", title: "Liked Events")
                        }

                        NavigationLink {
                            MyEventsView(mode: .submittedOnly)
                        } label: {
                            HubRectButton(icon: "calendar.badge.clock", title: "Submitted Events")
                        }

                        NavigationLink {
                            MyProfileView()
                        } label: {
                            HubRectButton(icon: "person.crop.circle.fill", title: "My Profile")
                        }

                        NavigationLink {
                            HelpView()
                        } label: {
                            HubRectButton(icon: "questionmark.circle.fill", title: "Help / How to Post")
                        }
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Settings button at bottom
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Text("Settings")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
        }
    }
}

// MARK: - Reusable rectangle button
struct HubRectButton: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .padding(10)
                .background(Color("LSERed")) // ✅ always LSE Red
                .clipShape(Circle())

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

// MARK: - Placeholder Views
struct MyEventsView: View {
    private struct ModeIntroduction {
        let icon: String
        let accent: Color
        let message: String
    }

    enum Mode {
        case all
        case likedOnly
        case submittedOnly

        fileprivate var initialTab: MyEventsViewModel.Tab {
            switch self {
            case .all, .likedOnly:
                return .liked
            case .submittedOnly:
                return .submitted
            }
        }

        fileprivate var availableTabs: [MyEventsViewModel.Tab] {
            switch self {
            case .all:
                return MyEventsViewModel.Tab.allCases
            case .likedOnly:
                return [.liked]
            case .submittedOnly:
                return [.submitted]
            }
        }

        fileprivate var navigationTitle: String {
            switch self {
            case .all:
                return "My Events"
            case .likedOnly:
                return "Liked Events"
            case .submittedOnly:
                return "Submitted Events"
            }
        }

        fileprivate var introduction: ModeIntroduction? {
            switch self {
            case .all:
                return nil
            case .likedOnly:
                return ModeIntroduction(
                    icon: "heart.fill",
                    accent: Color("LSERed"),
                    message: "Tap the heart on any event to keep it handy here — we'll sync your saved list everywhere you sign in."
                )
            case .submittedOnly:
                return ModeIntroduction(
                    icon: "calendar.badge.clock",
                    accent: .orange,
                    message: "Follow the approval journey of the events you've shared and make updates whenever plans change."
                )
            }
        }
    }

    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var eventsViewModel: PostListViewModel
    @StateObject private var viewModel = MyEventsViewModel()
    @State private var selectedTab: MyEventsViewModel.Tab
    @State private var activeAlert: AlertType?
    private let availableTabs: [MyEventsViewModel.Tab]
    private let navigationTitleText: String
    private let introduction: ModeIntroduction?

    init(mode: Mode = .all) {
        self.availableTabs = mode.availableTabs
        self.navigationTitleText = mode.navigationTitle
        self.introduction = mode.introduction
        _selectedTab = State(initialValue: mode.initialTab)
    }

    var body: some View {
        Group {
            if let token = authViewModel.token {
                eventsList(token: token)
            } else {
                loggedOutState
            }
        }
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: authViewModel.token) {
            if let token = authViewModel.token {
                await viewModel.loadEvents(token: token, reason: .initial)
            }
        }
        .onChange(of: viewModel.errorMessage) { _, message in
            guard let message else { return }
            activeAlert = .general(id: UUID(), message: message)
        }
        .onChange(of: viewModel.likeErrorMessage) { _, message in
            guard let message else { return }
            activeAlert = .like(id: UUID(), message: message)
        }
        .alert(item: $activeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK")) {
                    switch alert {
                    case .general:
                        viewModel.clearError()
                    case .like:
                        viewModel.clearLikeError()
                    }
                }
            )
        }
    }

    private var showsTabPicker: Bool {
        availableTabs.count > 1
    }

    private func eventsList(token: String) -> some View {
        let currentTab = availableTabs.contains(selectedTab) ? selectedTab : (availableTabs.first ?? .liked)
        let events = viewModel.events(for: currentTab)

        return List {
            if showsTabPicker {
                Section {
                    Picker("Event Type", selection: $selectedTab) {
                        ForEach(availableTabs) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            if let introduction {
                Section {
                    IntroHighlight(introduction: introduction)
                }
                .listRowInsets(EdgeInsets(top: showsTabPicker ? 0 : 12, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(events) { event in
                    switch currentTab {
                    case .liked:
                        NavigationLink {
                            PostDetailView(post: event, viewModel: eventsViewModel)
                        } label: {
                            LikedEventRow(
                                post: event,
                                isUpdatingLike: viewModel.isUpdatingLike(for: event.id),
                                onToggleLike: {
                                    Task { await viewModel.toggleLike(for: event, token: token) }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    case .submitted:
                        let display = statusDisplay(for: event)

                        MyEventRow(
                            post: event,
                            status: display,
                            isCancelling: viewModel.isCancelling(eventID: event.id),
                            isUpdatingLike: viewModel.isUpdatingLike(for: event.id),
                            onToggleLike: {
                                Task { await viewModel.toggleLike(for: event, token: token) }
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if display.kind == .pending {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.cancel(event: event, token: token)
                                    }
                                } label: {
                                    Label("Cancel", systemImage: "xmark.circle")
                                }
                                .disabled(viewModel.isCancelling(eventID: event.id))
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.refresh(token: token)
        }
        .overlay {
            if viewModel.isLoading && events.isEmpty {
                ProgressView("Loading events...")
                    .allowsHitTesting(false)
            } else if events.isEmpty {
                emptyState(for: currentTab)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) {
            if viewModel.isRefreshing && !events.isEmpty {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding(.top, 12)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }

    private var loggedOutState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Log in to view your events")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Your submissions will appear here once you're signed in with your LSE email.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func emptyState(for tab: MyEventsViewModel.Tab) -> some View {
        VStack(spacing: 12) {
            switch tab {
            case .liked:
                Image(systemName: "heart")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("No liked events yet")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Tap the heart on an event to save it here for quick access.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            case .submitted:
                Image(systemName: "calendar")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("No events yet")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Events you submit will show up here so you can track their status across devices.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private struct IntroHighlight: View {
        let introduction: ModeIntroduction

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: introduction.icon)
                    .font(.title3)
                    .foregroundColor(introduction.accent)
                    .padding(10)
                    .background(introduction.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(introduction.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
    }

    private func statusDisplay(for post: Post) -> StatusDisplay {
        switch post.statusKind {
        case .live:
            return StatusDisplay(title: "LIVE", kind: .live, color: .green)
        case .expired:
            return StatusDisplay(title: "Expired", kind: .expired, color: .gray)
        case .cancelled:
            return StatusDisplay(title: "Cancelled", kind: .cancelled, color: .red)
        case .pending:
            return StatusDisplay(title: "Pending Approval", kind: .pending, color: .orange)
        case .other(let raw):
            return StatusDisplay(title: raw.uppercased(), kind: .other(raw), color: .secondary)
        }
    }
    private enum AlertType: Identifiable {
        case general(id: UUID, message: String)
        case like(id: UUID, message: String)

        var id: UUID {
            switch self {
            case .general(let id, _), .like(let id, _):
                return id
            }
        }

        var title: String {
            switch self {
            case .general:
                return "Something Went Wrong"
            case .like:
                return "Unable to Save Event"
            }
        }

        var message: String {
            switch self {
            case .general(_, let message), .like(_, let message):
                return message
            }
        }
    }
}

private struct StatusDisplay {
    let title: String
    let kind: Post.StatusKind
    let color: Color
}

private struct MyEventRow: View {
    let post: Post
    let status: StatusDisplay
    let isCancelling: Bool
    let isUpdatingLike: Bool
    let onToggleLike: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(post.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                EventLikeButton(
                    isLiked: post.likedByMe,
                    likeCount: post.likesCount,
                    isLoading: isUpdatingLike,
                    action: onToggleLike
                )
            }

            HStack(spacing: 8) {
                if isCancelling {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.75)
                }

                Text(status.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(status.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(status.color.opacity(0.15))
                    .clipShape(Capsule())
            }

            Text(post.conciseScheduleString())
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let location = post.primaryLocationLine ?? post.location, !location.isEmpty {
                Text(location)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct LikedEventRow: View {
    let post: Post
    let isUpdatingLike: Bool
    let onToggleLike: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(post.title)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)

            Text(post.conciseScheduleString())
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let organization = post.organization, !organization.isEmpty {
                Text("by \(organization)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if let location = post.primaryLocationLine ?? post.location, !location.isEmpty {
                Text(location)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .overlay(alignment: .topTrailing) {
            EventLikeButton(
                isLiked: post.likedByMe,
                likeCount: post.likesCount,
                isLoading: isUpdatingLike,
                action: onToggleLike
            )
        }
    }
}

struct MyProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    private var emailText: String {
        let email = authViewModel.loggedInEmail ?? authViewModel.email
        return email.isEmpty ? "No email on file" : email
    }

    var body: some View {
        Form {
            Section(header: Text("LSE Email")) {
                Text(emailText)
                    .font(.body)
                    .textSelection(.enabled)
            }

            Section {
                Button(role: .destructive) {
                    authViewModel.logout()
                } label: {
                    Text("Log Out")
                        .font(.headline)
                }
            } footer: {
                Text("Logging out will require a new login code next time you open the app.")
            }
        }
        .navigationTitle("My Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings")
            .font(.largeTitle)
            .bold()
    }
}
