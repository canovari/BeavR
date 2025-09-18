import SwiftUI

struct FeedView: View {
    @ObservedObject var vm: PostListViewModel
    
    @State private var showFilterSheet = false
    @State private var selectedCategory: String? = nil
    @State private var selectedDate: Date? = nil
    
    // Single animation driver for all live indicators
    @State private var blink = false
    
    var filteredPosts: [Post] {
        vm.posts
            .filter { post in
                var include = true
                if let category = selectedCategory, !category.isEmpty {
                    include = include && (post.category == category)
                }
                if let date = selectedDate {
                    include = include && Calendar.current.isDate(post.startTime, inSameDayAs: date)
                }
                return include
            }
            .sorted(by: { $0.startTime < $1.startTime })
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredPosts) { post in
                            NavigationLink(destination: PostDetailView(post: post)) {
                                ZStack(alignment: .topTrailing) {
                                    // Background card
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("\(categoryEmoji(for: post.category)) \(post.title)")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        if let org = post.organization, !org.isEmpty {
                                            Text("by \(org)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        dateOrLiveView(for: post)
                                            .font(.subheadline)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                    .shadow(radius: 1)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                .refreshable {
                    do {
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    } catch {
                        return
                    }

                    guard !Task.isCancelled else { return }
                    await vm.refreshPosts()
                }

                if vm.posts.isEmpty && vm.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
            .navigationTitle("Feed")
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
                    selectedCategory: $selectedCategory,
                    selectedDate: $selectedDate
                )
            }
            .onAppear {
                // Start blinking loop
                blink = true
            }
            .onDisappear {
                blink = false
            }
        }
    }
    
    // MARK: - Helpers
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
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 14, height: 14)
                        .scaleEffect(blink ? 1.2 : 0.8)
                        .opacity(blink ? 0.2 : 0.8)

                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
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
}

// MARK: - Filter Sheet
struct FilterSheet: View {
    @Binding var selectedCategory: String?
    @Binding var selectedDate: Date?
    
    @Environment(\.dismiss) var dismiss
    
    let categories = [
        "Art Events 🎨", "Career 💼", "Club Events 🎉", "Cooking 👨‍🍳",
        "Cultural 🌍", "Festivals 🎊", "Freebie 😎", "Holiday ✨",
        "Ice Skating ⛸️", "Lectures 🎤", "Library 📚", "Movie 🎬", "Night Life 🎶",
        "Pride 🏳️‍🌈", "Shows 🎵", "Sports 🏀", "Trivia 🎲", "Wellness 🧘"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        Text("All").tag(String?.none)
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(Optional(cat))
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
}
