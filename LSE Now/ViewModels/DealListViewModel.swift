import Foundation

@MainActor
final class DealListViewModel: ObservableObject {
    @Published var deals: [Deal] = []
    @Published var isLoading: Bool = false

    private let dealsEndpoint = URL(string: "https://www.beavr.net/api/deals.php")!

    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }()

    func fetchDeals() {
        Task { [weak self] in
            await self?.refreshDeals()
        }
    }

    func refreshDeals() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let fetchedDeals = try await requestDeals(decoder: decoder)
            deals = fetchedDeals
        } catch {
            print("❌ Failed to fetch deals:", error.localizedDescription)
        }
    }

    private func requestDeals(decoder: JSONDecoder) async throws -> [Deal] {
        var request = URLRequest(url: dealsEndpoint)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request, delegate: nil)

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try decoder.decode([Deal].self, from: data)
    }
}
