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
                            MyEventsView()
                        } label: {
                            HubRectButton(icon: "calendar", title: "My Events")
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
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = MyEventsViewModel()
    @State private var alertMessage: String?

    var body: some View {
        Group {
            if let token = authViewModel.token {
                eventsList(token: token)
            } else {
                loggedOutState
            }
        }
        .navigationTitle("My Events")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: authViewModel.token) { token in
            guard let token = token else { return }
            await viewModel.loadEvents(token: token)
        }
        .onChange(of: viewModel.errorMessage) { message in
            alertMessage = message
        }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { alertMessage != nil },
            set: { newValue in
                if !newValue {
                    alertMessage = nil
                    viewModel.clearError()
                }
            }
        )) {
            Button("OK", role: .cancel) {
                alertMessage = nil
                viewModel.clearError()
            }
        } message: {
            Text(alertMessage ?? "An unknown error occurred.")
        }
    }

    @ViewBuilder
    private func eventsList(token: String) -> some View {
        List {
            ForEach(viewModel.events) { event in
                let display = statusDisplay(for: event)

                MyEventRow(
                    post: event,
                    status: display,
                    isCancelling: viewModel.isCancelling(eventID: event.id)
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if display.normalized == "pending" {
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
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.refresh(token: token)
        }
        .overlay {
            if viewModel.isLoading && viewModel.events.isEmpty {
                ProgressView("Loading events...")
                    .allowsHitTesting(false)
            } else if viewModel.events.isEmpty {
                emptyState
                    .allowsHitTesting(false)
            }
        }
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

    private var emptyState: some View {
        VStack(spacing: 12) {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func statusDisplay(for post: Post) -> StatusDisplay {
        var normalized = post.status?.lowercased() ?? "pending"
        if post.isExpired() {
            normalized = "expired"
        }

        switch normalized {
        case "live":
            return StatusDisplay(title: "LIVE", normalized: normalized, color: .green)
        case "expired":
            return StatusDisplay(title: "Expired", normalized: normalized, color: .gray)
        default:
            return StatusDisplay(title: "Pending Approval", normalized: "pending", color: .orange)
        }
    }
}

private struct StatusDisplay {
    let title: String
    let normalized: String
    let color: Color
}

private struct MyEventRow: View {
    let post: Post
    let status: StatusDisplay
    let isCancelling: Bool

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(post.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

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
            }

            Text(dateRangeText)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let location = post.location, !location.isEmpty {
                Text(location)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }

    private var dateRangeText: String {
        if let end = post.endTime {
            let start = post.startTime
            if calendar.isDate(start, inSameDayAs: end) {
                return "\(start.formatted(date: .abbreviated, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
            } else {
                return "\(start.formatted(date: .abbreviated, time: .shortened)) – \(end.formatted(date: .abbreviated, time: .shortened))"
            }
        } else {
            return post.startTime.formatted(date: .abbreviated, time: .shortened)
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
