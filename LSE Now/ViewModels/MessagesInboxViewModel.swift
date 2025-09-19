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

        defer { isLoading = false }

        do {
            let fetched = try await apiService.fetchMessages(folder: folder.serviceFolder, token: token)
            messages = fetched
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Ignore cancellations triggered by switching folders or dismissing the sheet.
        } catch is CancellationError {
            // Ignore explicit cancellation errors from Swift concurrency.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
