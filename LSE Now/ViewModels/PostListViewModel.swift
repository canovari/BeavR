import Foundation

@MainActor
class PostListViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading: Bool = false

    private var allPosts: [Post] = []
    private var expiryTimer: Timer?
    private let expiryCheckInterval: TimeInterval = 60
    private var refreshTask: Task<Void, Never>?
    private let session: URLSession

    private static let minimumUserRefreshDelay: TimeInterval = 1

    init(session: URLSession = .shared) {
        self.session = session
    }

    deinit {
        expiryTimer?.invalidate()
        refreshTask?.cancel()
    }

    func fetchPosts(enforceMinimumDelay: Bool = false) {
        guard !isLoading else { return }
        let minimumDelay = enforceMinimumDelay ? Self.minimumUserRefreshDelay : nil
        startBackgroundRefresh(minimumDelay: minimumDelay)
    }

    func refreshPosts(enforceMinimumDelay: Bool = false) async {
        let minimumDelay = enforceMinimumDelay ? Self.minimumUserRefreshDelay : nil
        refreshTask?.cancel()
        refreshTask = nil
        await performRefresh(minimumDelay: minimumDelay, clearsBackgroundTask: false)
    }

    private func startBackgroundRefresh(minimumDelay: TimeInterval?) {
        if let existingTask = refreshTask, !existingTask.isCancelled {
            return
        }

        refreshTask?.cancel()
        refreshTask = Task {
            await performRefresh(minimumDelay: minimumDelay, clearsBackgroundTask: true)
        }
    }

    private func performRefresh(minimumDelay: TimeInterval?, clearsBackgroundTask: Bool) async {
        guard let url = URL(string: "https://www.canovari.com/api/events.php") else { return }

        isLoading = true
        let refreshStart = Date()
        defer {
            isLoading = false
            if clearsBackgroundTask {
                refreshTask = nil
            }
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let (data, _) = try await session.data(from: url)

            if let raw = String(data: data, encoding: .utf8) {
                print("📥 Raw API response:", raw)
            }

            let decodedPosts = try decoder.decode([Post].self, from: data)

            if let minimumDelay {
                let elapsed = Date().timeIntervalSince(refreshStart)
                if elapsed < minimumDelay {
                    let remaining = minimumDelay - elapsed
                    let nanoseconds = UInt64(remaining * 1_000_000_000)
                    if nanoseconds > 0 {
                        try await Task.sleep(nanoseconds: nanoseconds)
                    }
                }
            }

            print("✅ Decoded posts count:", decodedPosts.count)
            allPosts = decodedPosts
            applyExpiryPolicy()
            print("📦 Active posts after expiry filter:", posts.count)
            startExpiryTimer()
        } catch is CancellationError {
            return
        } catch let urlError as URLError {
            if urlError.code == .cancelled {
                return
            }
            print("❌ Network error:", urlError.localizedDescription)
        } catch let decodingError as DecodingError {
            print("❌ Decoding error:", decodingError)
        } catch {
            print("❌ Unexpected error:", error.localizedDescription)
        }
    }

    private func applyExpiryPolicy(referenceDate: Date = Date()) {
        guard !allPosts.isEmpty else {
            if !posts.isEmpty {
                posts = []
            }
            stopExpiryTimer()
            return
        }

        let processedPosts = allPosts.map { $0.updatingStatusForExpiry(referenceDate: referenceDate) }
        allPosts = processedPosts

        let previousCount = posts.count
        let activePosts = processedPosts.filter { !$0.isExpired(referenceDate: referenceDate) }
        posts = activePosts

        let removedCount = max(0, previousCount - activePosts.count)
        if removedCount > 0 {
            print("🕒 Expired posts removed:", removedCount)
        }

        if activePosts.isEmpty {
            stopExpiryTimer()
        }
    }

    private func startExpiryTimer() {
        stopExpiryTimer()
        guard !posts.isEmpty else { return }

        expiryTimer = Timer.scheduledTimer(withTimeInterval: expiryCheckInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.applyExpiryPolicy()
            }
        }
    }

    private func stopExpiryTimer() {
        expiryTimer?.invalidate()
        expiryTimer = nil
    }
}
