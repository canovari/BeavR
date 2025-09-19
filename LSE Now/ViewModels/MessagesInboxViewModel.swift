import Foundation

@MainActor
final class MessagesInboxViewModel: ObservableObject {
    enum Folder: String, CaseIterable {
        case received
        case sent

        var title: String {
            switch self {
            case .received:
                return "Received"
            case .sent:
                return "Sent"
            }
        }

        var serviceFolder: APIService.MessageFolder {
            switch self {
            case .received:
                return .received
            case .sent:
                return .sent
            }
        }
    }

    @Published private(set) var messages: [WhiteboardMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService: APIService

    init(apiService: APIService = .shared) {
        self.apiService = apiService
    }

    func fetchMessages(folder: Folder, token: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await apiService.fetchMessages(folder: folder.serviceFolder, token: token)
            messages = fetched
        } catch {
            errorMessage = error.localizedDescription
            messages = []
        }

        isLoading = false
    }
}
