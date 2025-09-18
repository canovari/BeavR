import Foundation

@MainActor
class PostListViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading: Bool = false

    private var allPosts: [Post] = []
    private var expiryTimer: Timer?
    private let expiryCheckInterval: TimeInterval = 60

    deinit {
        expiryTimer?.invalidate()
    }

    func fetchPosts() {
        Task {
            await refreshPosts()
        }
    }

    func refreshPosts() async {
        guard !isLoading else { return }
        guard let url = URL(string: "https://www.canovari.com/api/events.php") else { return }

        isLoading = true
        defer { isLoading = false }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            if let raw = String(data: data, encoding: .utf8) {
                print("📥 Raw API response:", raw)
            }

            let decodedPosts = try decoder.decode([Post].self, from: data)

            print("✅ Decoded posts count:", decodedPosts.count)
            allPosts = decodedPosts
            applyExpiryPolicy()
            print("📦 Active posts after expiry filter:", posts.count)
            startExpiryTimer()
        } catch let urlError as URLError {
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
