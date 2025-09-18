import Foundation

class PostListViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading: Bool = false

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
                let result = try decoder.decode([Post].self, from: data)
                DispatchQueue.main.async {
                    print("✅ Decoded posts count:", result.count)
                    self.posts = result
                }
            } catch {
                print("❌ Decoding error:", error)
            }
        }.resume()
    }

}
