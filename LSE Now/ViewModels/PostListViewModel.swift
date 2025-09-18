import Foundation

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
        isLoading = true
        guard let url = URL(string: "https://www.canovari.com/api/events.php") else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            if let error = error {
                print("❌ Network error:", error.localizedDescription)
                return
            }
            guard let data = data else {
                print("❌ No data received")
                return
            }

            // Debug raw response
            if let raw = String(data: data, encoding: .utf8) {
                print("📥 Raw API response:", raw)
            }

            do {
                let decodedPosts = try decoder.decode([Post].self, from: data)

                DispatchQueue.main.async {
                    print("✅ Decoded posts count:", decodedPosts.count)
                    self.allPosts = decodedPosts
                    self.applyExpiryPolicy()
                    print("📦 Active posts after expiry filter:", self.posts.count)
                    self.startExpiryTimer()
                }
            } catch {
                print("❌ Decoding error:", error)
            }
        }.resume()
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
