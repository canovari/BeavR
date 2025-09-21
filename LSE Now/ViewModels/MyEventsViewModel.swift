import Foundation
import SwiftUI

@MainActor
final class MyEventsViewModel: ObservableObject {
    @Published private(set) var likedEvents: [Post] = []
    @Published private(set) var submittedEvents: [Post] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isRefreshing: Bool = false
    @Published private(set) var cancellingEventIDs: Set<Int> = []
    @Published private(set) var likeUpdatingIDs: Set<Int> = []
    @Published var errorMessage: String?
    @Published var likeErrorMessage: String?

    private let apiService: APIService
    private var likeChangeObserver: NSObjectProtocol?

    init(apiService: APIService = .shared) {
        self.apiService = apiService

        likeChangeObserver = NotificationCenter.default.addObserver(
            forName: .eventLikeStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            if let sender = notification.object as AnyObject?, sender === self { return }
            guard let change = EventLikeChange.from(notification) else { return }
            self.applyExternalLikeChange(change)
        }
    }

    deinit {
        if let likeChangeObserver {
            NotificationCenter.default.removeObserver(likeChangeObserver)
        }
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

        var likedResult: [Post]?
        var submittedResult: [Post]?
        var capturedError: Error?

        do {
            let liked = try await apiService.fetchLikedEvents(token: token)
            likedResult = prepareLikedEvents(liked)
        } catch {
            capturedError = error
        }

        do {
            let posts = try await apiService.fetchMyEvents(token: token)
            submittedResult = prepareSubmittedEvents(posts)
        } catch {
            capturedError = capturedError ?? error
        }

        if let likedResult {
            withAnimation(.easeInOut(duration: 0.2)) {
                likedEvents = likedResult
            }
        }

        if let submittedResult {
            withAnimation(.easeInOut(duration: 0.2)) {
                submittedEvents = submittedResult
            }
        }

        if let capturedError {
            errorMessage = capturedError.localizedDescription
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
            withAnimation(.easeInOut(duration: 0.2)) {
                submittedEvents.removeAll { $0.id == event.id }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLike(for post: Post, token: String) async {
        guard !likeUpdatingIDs.contains(post.id) else { return }

        likeUpdatingIDs.insert(post.id)
        defer { likeUpdatingIDs.remove(post.id) }

        likeErrorMessage = nil

        let baseline = currentPost(withID: post.id) ?? post
        let targetIsLiked = !baseline.likedByMe

        do {
            if targetIsLiked {
                try await apiService.likeEvent(id: post.id, token: token)
            } else {
                try await apiService.unlikeEvent(id: post.id, token: token)
            }

            let delta = targetIsLiked ? 1 : -1
            let newCount = max(0, baseline.likesCount + delta)
            updateLocalLikeState(eventID: post.id, liked: targetIsLiked, likeCount: newCount)

            if targetIsLiked {
                if !likedEvents.contains(where: { $0.id == post.id }) {
                    if let updated = currentPost(withID: post.id) ?? submittedEvents.first(where: { $0.id == post.id }) {
                        let prepared = updated.updatingStatusForExpiry()
                        if !prepared.isExpired() {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                likedEvents.append(prepared)
                                likedEvents = sortLikedEvents(likedEvents)
                            }
                        }
                    } else {
                        let prepared = baseline
                            .updatingLikeState(likesCount: newCount, likedByMe: true)
                            .updatingStatusForExpiry()
                        if !prepared.isExpired() {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                likedEvents.append(prepared)
                                likedEvents = sortLikedEvents(likedEvents)
                            }
                        }
                    }
                } else {
                    likedEvents = sortLikedEvents(likedEvents)
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    likedEvents.removeAll { $0.id == post.id }
                }
            }

            if let updated = currentPost(withID: post.id) {
                EventLikeChange.post(
                    from: self,
                    eventID: post.id,
                    isLiked: targetIsLiked,
                    likeCount: updated.likesCount,
                    post: updated
                )
            } else {
                let fallback = baseline.updatingLikeState(likesCount: newCount, likedByMe: targetIsLiked)
                EventLikeChange.post(
                    from: self,
                    eventID: post.id,
                    isLiked: targetIsLiked,
                    likeCount: newCount,
                    post: fallback
                )
            }
        } catch {
            likeErrorMessage = error.localizedDescription
        }
    }

    func events(for tab: Tab) -> [Post] {
        switch tab {
        case .liked:
            return likedEvents
        case .submitted:
            return submittedEvents
        }
    }

    func isCancelling(eventID: Int) -> Bool {
        cancellingEventIDs.contains(eventID)
    }

    func isUpdatingLike(for eventID: Int) -> Bool {
        likeUpdatingIDs.contains(eventID)
    }

    func clearError() {
        errorMessage = nil
    }

    func clearLikeError() {
        likeErrorMessage = nil
    }

    enum LoadReason {
        case initial
        case refresh
    }

    enum Tab: String, CaseIterable, Identifiable {
        case liked
        case submitted

        var id: String { rawValue }

        var title: String {
            switch self {
            case .liked:
                return "Liked"
            case .submitted:
                return "Submitted"
            }
        }
    }

    private func prepareLikedEvents(_ posts: [Post]) -> [Post] {
        posts
            .map { $0.updatingStatusForExpiry() }
            .filter { !$0.isExpired() }
            .sorted { $0.startTime < $1.startTime }
    }

    private func prepareSubmittedEvents(_ posts: [Post]) -> [Post] {
        sortSubmittedEvents(posts.map { $0.updatingStatusForExpiry() })
    }

    private func sortSubmittedEvents(_ posts: [Post]) -> [Post] {
        posts.sorted { lhs, rhs in
            let leftPriority = statusPriority(for: lhs)
            let rightPriority = statusPriority(for: rhs)

            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }

            return lhs.startTime < rhs.startTime
        }
    }

    private func sortLikedEvents(_ posts: [Post]) -> [Post] {
        posts.sorted { lhs, rhs in
            lhs.startTime < rhs.startTime
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

    private func currentPost(withID id: Int) -> Post? {
        if let match = likedEvents.first(where: { $0.id == id }) {
            return match
        }
        return submittedEvents.first(where: { $0.id == id })
    }

    private func updateLocalLikeState(eventID: Int, liked: Bool, likeCount: Int) {
        let sanitizedCount = max(0, likeCount)

        func update(list: inout [Post]) {
            guard let index = list.firstIndex(where: { $0.id == eventID }) else { return }
            list[index] = list[index].updatingLikeState(likesCount: sanitizedCount, likedByMe: liked)
        }

        update(list: &submittedEvents)
        update(list: &likedEvents)
    }

    private func updatePost(_ post: Post) {
        func update(list: inout [Post]) {
            guard let index = list.firstIndex(where: { $0.id == post.id }) else { return }
            list[index] = post
        }

        update(list: &submittedEvents)
        update(list: &likedEvents)
    }

    private func applyExternalLikeChange(_ change: EventLikeChange) {
        if let updatedPost = change.post {
            updatePost(updatedPost)
        } else {
            updateLocalLikeState(eventID: change.eventID, liked: change.isLiked, likeCount: change.likeCount)
        }

        if change.isLiked {
            if let updated = change.post?.updatingStatusForExpiry(), !updated.isExpired() {
                if !likedEvents.contains(where: { $0.id == change.eventID }) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        likedEvents.append(updated)
                        likedEvents = sortLikedEvents(likedEvents)
                    }
                } else {
                    likedEvents = sortLikedEvents(likedEvents)
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                likedEvents.removeAll { $0.id == change.eventID }
            }
        }
    }
}
