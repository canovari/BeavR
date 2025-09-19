import Foundation

@MainActor
final class MyEventsViewModel: ObservableObject {
    @Published private(set) var events: [Post] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var cancellingEventIDs: Set<Int> = []
    @Published var errorMessage: String?

    private let apiService: APIService

    init(apiService: APIService = .shared) {
        self.apiService = apiService
    }

    func loadEvents(token: String) async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        errorMessage = nil

        do {
            let posts = try await apiService.fetchMyEvents(token: token)
            events = sortEvents(posts)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh(token: String) async {
        await loadEvents(token: token)
    }

    func cancel(event: Post, token: String) async {
        guard !cancellingEventIDs.contains(event.id) else { return }

        cancellingEventIDs.insert(event.id)
        defer { cancellingEventIDs.remove(event.id) }

        errorMessage = nil

        do {
            try await apiService.cancelEvent(id: event.id, token: token)
            events.removeAll { $0.id == event.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isCancelling(eventID: Int) -> Bool {
        cancellingEventIDs.contains(eventID)
    }

    func clearError() {
        errorMessage = nil
    }

    private func sortEvents(_ posts: [Post]) -> [Post] {
        posts.sorted { lhs, rhs in
            let leftPriority = statusPriority(for: lhs)
            let rightPriority = statusPriority(for: rhs)

            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }

            return lhs.startTime < rhs.startTime
        }
    }

    private func statusPriority(for post: Post) -> Int {
        switch normalizedStatus(for: post) {
        case "pending":
            return 0
        case "live":
            return 1
        case "expired":
            return 2
        default:
            return 3
        }
    }

    private func normalizedStatus(for post: Post) -> String {
        if post.isExpired() {
            return "expired"
        }
        return post.status?.lowercased() ?? "pending"
    }
}
