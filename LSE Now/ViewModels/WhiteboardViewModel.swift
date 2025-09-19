import Foundation

@MainActor
final class WhiteboardViewModel: ObservableObject {
    @Published private(set) var pins: [WhiteboardPin] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSubmittingPin = false
    @Published var isSendingReply = false

    private let apiService: APIService

    init(apiService: APIService = .shared) {
        self.apiService = apiService
    }

    func pin(at coordinate: WhiteboardCoordinate) -> WhiteboardPin? {
        pins.first { $0.gridRow == coordinate.row && $0.gridCol == coordinate.column }
    }

    func loadPins() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let fetchedPins = try await apiService.fetchPins()
            pins = fetchedPins
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func createPin(emoji: String, text: String, author: String?, at coordinate: WhiteboardCoordinate, token: String) async throws {
        guard !isSubmittingPin else { return }

        isSubmittingPin = true
        defer { isSubmittingPin = false }

        let request = CreatePinRequest(
            emoji: emoji,
            text: text,
            author: author,
            gridRow: coordinate.row,
            gridCol: coordinate.column
        )

        let newPin = try await apiService.createPin(request: request, token: token)
        pins.removeAll { $0.gridRow == newPin.gridRow && $0.gridCol == newPin.gridCol }
        pins.append(newPin)
    }

    func sendReply(to pin: WhiteboardPin, message: String, author: String?, token: String) async throws {
        guard !isSendingReply else { return }

        isSendingReply = true
        defer { isSendingReply = false }

        let payload = PinReplyPayload(pinId: pin.id, message: message, author: author)
        _ = try await apiService.sendPinReply(payload: payload, token: token)
    }
}
