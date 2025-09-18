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
                            DraftsView()
                        } label: {
                            HubRectButton(icon: "doc.text.fill", title: "Drafts")
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
    var body: some View {
        Text("My Events")
            .font(.largeTitle)
            .bold()
    }
}

struct DraftsView: View {
    var body: some View {
        Text("Drafts")
            .font(.largeTitle)
            .bold()
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings")
            .font(.largeTitle)
            .bold()
    }
}
