import Foundation

enum WhiteboardGridConfiguration {
    static let rows = 8
    static let columns = 5

    static func contains(row: Int, column: Int) -> Bool {
        row >= 0 && row < rows && column >= 0 && column < columns
    }
}

enum WhiteboardViewModelError: LocalizedError {
    case missingCreatorEmail
    case pinLimitReached

    var errorDescription: String? {
        switch self {
        case .missingCreatorEmail:
            return "We couldn't verify who created this pin. Please log in again and try posting."
        case .pinLimitReached:
            return "You already have a live pin. Delete it or wait for it to expire before posting another."
        }
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

    func activePinCount(forCreatorEmail email: String?, referenceDate: Date = Date()) -> Int {
        guard let normalized = normalizedCreatorEmail(from: email) else { return 0 }
        return pins.reduce(into: 0) { count, pin in
            if pin.creatorEmail == normalized && !pin.isExpired(referenceDate: referenceDate) {
                count += 1
            }
        }
    }

    func firstActivePin(forCreatorEmail email: String?, referenceDate: Date = Date()) -> WhiteboardPin? {
        guard let normalized = normalizedCreatorEmail(from: email) else { return nil }
        return firstActivePin(forNormalizedCreatorEmail: normalized, referenceDate: referenceDate)
    }

    func hasActivePin(forCreatorEmail email: String?, referenceDate: Date = Date()) -> Bool {
        guard let normalized = normalizedCreatorEmail(from: email) else { return false }
        return hasActivePin(forNormalizedCreatorEmail: normalized, referenceDate: referenceDate)
    }

    func loadPins(forceReload: Bool = false) async {
        if isLoading {
            guard forceReload else {
                print("⚠️ loadPins called while already loading (no forceReload)")
                return
            }

            print("⏳ Waiting for current load to finish before forceReload")
            while isLoading {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }

        isLoading = true
        errorMessage = nil
        print("🔄 loadPins starting (forceReload=\(forceReload))")

        defer {
            isLoading = false
            print("✅ loadPins finished. pin count=\(pins.count)")
        }

        do {
            // Detached so SwiftUI refresh cancellation won't kill it
            let fetchedPins = try await Task.detached(priority: .userInitiated) { [apiService] in
                print("🌐 Fetching pins from API (forceReload=\(forceReload))")
                return try await apiService.fetchPins(
                    cacheBustingToken: forceReload ? UUID().uuidString : nil
                )
            }.value

            print("📥 loadPins fetched \(fetchedPins.count) pins from server")

            let normalizedPins = fetchedPins
                .filter { WhiteboardGridConfiguration.contains(row: $0.gridRow, column: $0.gridCol) }
                .map { pinWithCreatorAuthor($0) }

            pins = normalizedPins
            maintainExpirationTimer()

            print("📌 loadPins normalized pins count=\(pins.count)")

        } catch let urlError as URLError where urlError.code == .cancelled {
            print("⛔️ loadPins cancelled (URLError.cancelled)")
        } catch is CancellationError {
            print("⛔️ loadPins cancelled (CancellationError)")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ loadPins error: \(error.localizedDescription)")
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

        guard let normalizedCreator = normalizedCreatorEmail(from: creatorEmail) else {
            print("❌ createPin aborted — missing creator email")
            throw WhiteboardViewModelError.missingCreatorEmail
        }

        guard !hasActivePin(forNormalizedCreatorEmail: normalizedCreator) else {
            print("❌ createPin aborted — live pin limit reached for \(normalizedCreator)")
            throw WhiteboardViewModelError.pinLimitReached
        }

        let request = CreatePinRequest(
            emoji: emoji,
            text: text,
            author: author,
            creatorEmail: normalizedCreator,
            gridRow: coordinate.row,
            gridCol: coordinate.column
        )

        let newPin = try await apiService.createPin(request: request, token: token)
        let finalPin = WhiteboardPin(
            id: newPin.id,
            emoji: newPin.emoji,
            text: newPin.text,
            author: newPin.author,
            creatorEmail: normalizedCreator,
            gridRow: newPin.gridRow,
            gridCol: newPin.gridCol,
            createdAt: newPin.createdAt
        )

        guard WhiteboardGridConfiguration.contains(row: newPin.gridRow, column: newPin.gridCol) else {
            print("⚠️ Ignoring pin outside grid")
            return
        }

        pins.removeAll { $0.gridRow == newPin.gridRow && $0.gridCol == newPin.gridCol }
        pins.append(pinWithCreatorAuthor(finalPin))
        maintainExpirationTimer()
        print("➕ Added new pin at (\(newPin.gridRow),\(newPin.gridCol)). Total now=\(pins.count)")
    }

    private func firstActivePin(forNormalizedCreatorEmail normalized: String, referenceDate: Date = Date()) -> WhiteboardPin? {
        pins.first { $0.creatorEmail == normalized && !$0.isExpired(referenceDate: referenceDate) }
    }

    private func hasActivePin(forNormalizedCreatorEmail normalized: String, referenceDate: Date = Date()) -> Bool {
        firstActivePin(forNormalizedCreatorEmail: normalized, referenceDate: referenceDate) != nil
    }

    private func normalizedCreatorEmail(from rawEmail: String?) -> String? {
        guard let rawEmail else { return nil }
        let trimmed = rawEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    func deletePin(_ pin: WhiteboardPin, token: String) async throws {
        print("🗑️ Deleting pin id=\(pin.id)")
        do {
            try await apiService.deletePin(id: pin.id, token: token)
            pins.removeAll { $0.id == pin.id }

            if pins.isEmpty {
                expirationTimer?.invalidate()
                expirationTimer = nil
            }

            print("✅ Deleted pin id=\(pin.id). Remaining pins=\(pins.count)")
        } catch {
            print("❌ Failed to delete pin id=\(pin.id): \(error.localizedDescription)")
            throw error
        }
    }

    func sendReply(to pin: WhiteboardPin, message: String, author: String?, token: String) async throws {
        guard !isSendingReply else { return }

        isSendingReply = true
        defer { isSendingReply = false }

        let payload = PinReplyPayload(pinId: pin.id, message: message, author: author)
        print("✉️ Sending reply to pin \(pin.id)")
        _ = try await apiService.sendPinReply(payload: payload, token: token)
        print("✅ Reply sent")
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
            print("🗑️ Pruned \(pins.count - activePins.count) expired pins")
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

        let sanitizedAuthor = WhiteboardDecoding.sanitized(pin.author)

        let finalAuthor: String?
        if let sanitizedAuthor {
            let normalizedAuthor = sanitizedAuthor
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if !normalizedCreator.isEmpty && normalizedAuthor == normalizedCreator {
                finalAuthor = nil
            } else {
                finalAuthor = sanitizedAuthor
            }
        } else {
            finalAuthor = nil
        }

        return WhiteboardPin(
            id: pin.id,
            emoji: pin.emoji,
            text: pin.text,
            author: finalAuthor,
            creatorEmail: normalizedCreator.isEmpty ? pin.creatorEmail : normalizedCreator,
            gridRow: pin.gridRow,
            gridCol: pin.gridCol,
            createdAt: pin.createdAt
        )
    }
}
