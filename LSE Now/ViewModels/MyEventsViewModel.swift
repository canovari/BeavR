import Foundation
import SwiftUI

@MainActor
final class MyEventsViewModel: ObservableObject {
    @Published private(set) var events: [Post] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isRefreshing: Bool = false
    @Published private(set) var cancellingEventIDs: Set<Int> = []
    @Published var errorMessage: String?

    private let apiService: APIService

    init(apiService: APIService = .shared) {
        self.apiService = apiService
    }

    func loadEvents(token: String, reason: LoadReason = .initial) async {
        switch reason {
        case .initial:
            guard !isLoading else { return }
            isLoading = true
        case .refresh:
            guard !isRefreshing, !isLoading else { return }
            isRefreshing = true
        }

        defer {
            switch reason {
            case .initial:
                isLoading = false
            case .refresh:
                isRefreshing = false
            }
        }

        errorMessage = nil

        do {
            let posts = try await apiService.fetchMyEvents(token: token)
            let prepared = posts.map { $0.updatingStatusForExpiry() }
            withAnimation(.easeInOut(duration: 0.2)) {
                events = sortEvents(prepared)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh(token: String) async {
        await loadEvents(token: token, reason: .refresh)
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
        switch post.statusKind {
        case .pending:
            return 0
        case .live:
            return 1
        case .expired:
            return 2
        case .cancelled:
            return 3
        default:
            return 4
        }
    }

    enum LoadReason {
        case initial
        case refresh
    }
}
