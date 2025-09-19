import Foundation

enum WhiteboardGridConfiguration {
    static let rows = 8
    static let columns = 5

    static func contains(row: Int, column: Int) -> Bool {
        row >= 0 && row < rows && column >= 0 && column < columns
    }
}

@MainActor
final class WhiteboardViewModel: ObservableObject {
    @Published private(set) var pins: [WhiteboardPin] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSubmittingPin = false
    @Published var isSendingReply = false

    private let apiService: APIService
    private var expirationTimer: Timer?
    private let expirationCheckInterval: TimeInterval = 60

    init(apiService: APIService = .shared) {
        self.apiService = apiService
    }

    func pin(at coordinate: WhiteboardCoordinate) -> WhiteboardPin? {
        guard WhiteboardGridConfiguration.contains(row: coordinate.row, column: coordinate.column) else {
            return nil
        }
        let now = Date()
        return pins.first { pin in
            pin.gridRow == coordinate.row &&
            pin.gridCol == coordinate.column &&
            !pin.isExpired(referenceDate: now)
        }
    }

    func loadPins(forceReload: Bool = false) async {
        if isLoading {
            guard forceReload else { return }

            while isLoading {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let fetchedPins = try await apiService.fetchPins(
                cacheBustingToken: forceReload ? UUID().uuidString : nil
            )
            let normalizedPins = fetchedPins
                .filter { WhiteboardGridConfiguration.contains(row: $0.gridRow, column: $0.gridCol) }
                .map { pinWithCreatorAuthor($0) }
            pins = normalizedPins
            maintainExpirationTimer()
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Ignore cancellations that happen during refreshes.
        } catch is CancellationError {
            // Ignore explicit cancellation errors triggered by SwiftUI task lifecycle.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createPin(
        emoji: String,
        text: String,
        author: String?,
        at coordinate: WhiteboardCoordinate,
        token: String,
        creatorEmail: String?
    ) async throws {
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
        let normalizedCreator = creatorEmail?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let finalPin: WhiteboardPin
        if let normalizedCreator, !normalizedCreator.isEmpty {
            finalPin = WhiteboardPin(
                id: newPin.id,
                emoji: newPin.emoji,
                text: newPin.text,
                author: newPin.author,
                creatorEmail: normalizedCreator,
                gridRow: newPin.gridRow,
                gridCol: newPin.gridCol,
                createdAt: newPin.createdAt
            )
        } else {
            finalPin = newPin
        }

        guard WhiteboardGridConfiguration.contains(row: newPin.gridRow, column: newPin.gridCol) else {
            return
        }
        pins.removeAll { $0.gridRow == newPin.gridRow && $0.gridCol == newPin.gridCol }
        pins.append(pinWithCreatorAuthor(finalPin))
        maintainExpirationTimer()
    }

    func sendReply(to pin: WhiteboardPin, message: String, author: String?, token: String) async throws {
        guard !isSendingReply else { return }

        isSendingReply = true
        defer { isSendingReply = false }

        let payload = PinReplyPayload(pinId: pin.id, message: message, author: author)
        _ = try await apiService.sendPinReply(payload: payload, token: token)
    }

    deinit {
        expirationTimer?.invalidate()
    }

    private func maintainExpirationTimer() {
        pruneExpiredPins()

        if pins.isEmpty {
            expirationTimer?.invalidate()
            expirationTimer = nil
            return
        }

        guard expirationTimer == nil else { return }

        expirationTimer = Timer.scheduledTimer(withTimeInterval: expirationCheckInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.pruneExpiredPins()
            }
        }
    }

    private func pruneExpiredPins(referenceDate: Date = Date()) {
        let activePins = pins.filter { !$0.isExpired(referenceDate: referenceDate) }
        if activePins.count != pins.count {
            pins = activePins
        }

        if activePins.isEmpty {
            expirationTimer?.invalidate()
            expirationTimer = nil
        }
    }

    private func pinWithCreatorAuthor(_ pin: WhiteboardPin) -> WhiteboardPin {
        let normalizedCreator = pin.creatorEmail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let fallbackAuthor: String?
        if normalizedCreator.isEmpty {
            let trimmedAuthor = pin.author?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            fallbackAuthor = (trimmedAuthor?.isEmpty == false) ? trimmedAuthor : nil
        } else {
            fallbackAuthor = normalizedCreator
        }

        return WhiteboardPin(
            id: pin.id,
            emoji: pin.emoji,
            text: pin.text,
            author: fallbackAuthor,
            creatorEmail: normalizedCreator.isEmpty ? pin.creatorEmail : normalizedCreator,
            gridRow: pin.gridRow,
            gridCol: pin.gridCol,
            createdAt: pin.createdAt
        )
    }
}
