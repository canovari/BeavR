import Foundation

@MainActor
class PostListViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading: Bool = false

    private var allPosts: [Post] = []
    private var expiryTimer: Timer?
    private var cancellationRetryTask: Task<Void, Never>?
    private let expiryCheckInterval: TimeInterval = 60

    private let eventsEndpoint = URL(string: "https://www.canovari.com/api/events.php")!
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }()

    private enum FetchError: LocalizedError {
        case invalidResponse
        case invalidStatus(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response from the server."
            case .invalidStatus(let code):
                return "Server responded with status code \(code)."
            }
        }
    }

    deinit {
        cancellationRetryTask?.cancel()
        expiryTimer?.invalidate()
    }

    func fetchPosts() {
        Task {
            await refreshPosts()
        }
    }

    func refreshPosts(allowRetryAfterCancellation: Bool = true) async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let decodedPosts = try await fetchRemotePosts(using: decoder)

            print("✅ Decoded posts count:", decodedPosts.count)
            allPosts = decodedPosts
            applyExpiryPolicy()
            print("📦 Active posts after expiry filter:", posts.count)
            startExpiryTimer()
        } catch let fetchError as FetchError {
            print("❌ Network error:", fetchError.localizedDescription)
        } catch let urlError as URLError {
            if urlError.code == .cancelled {
                print("⚠️ Network request was cancelled.")
            } else {
                print("❌ Network error:", urlError.localizedDescription)
            }
        } catch let decodingError as DecodingError {
            print("❌ Decoding error:", decodingError)
        } catch is CancellationError {
            print("⚠️ Refresh task was cancelled")
            if allowRetryAfterCancellation {
                scheduleRetryAfterCancellation()
            }
        } catch {
            print("❌ Unexpected error:", error.localizedDescription)
        }
    }

    private func fetchRemotePosts(using decoder: JSONDecoder, retryOnCancellation: Bool = true) async throws -> [Post] {
        var request = URLRequest(url: eventsEndpoint)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await urlSession.data(for: request, delegate: nil)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw FetchError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw FetchError.invalidStatus(httpResponse.statusCode)
            }

            if let raw = String(data: data, encoding: .utf8) {
                print("📥 Raw API response:", raw)
            }

            return try decoder.decode([Post].self, from: data)
        } catch let urlError as URLError where urlError.code == .cancelled && retryOnCancellation {
            if Task.isCancelled {
                throw CancellationError()
            }

            print("⚠️ Request cancelled mid-refresh. Retrying once...")
            try await Task.sleep(nanoseconds: 200_000_000)
            return try await fetchRemotePosts(using: decoder, retryOnCancellation: false)
        } catch {
            throw error
        }
    }

    private func scheduleRetryAfterCancellation() {
        print("🔄 Scheduling retry after cancellation...")
        cancellationRetryTask?.cancel()

        cancellationRetryTask = Task.detached(priority: nil) { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)

            guard let self = self else { return }

            await self.refreshPosts(allowRetryAfterCancellation: false)
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
