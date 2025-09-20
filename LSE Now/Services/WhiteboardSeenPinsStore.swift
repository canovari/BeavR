import Combine
import Foundation

@MainActor
final class WhiteboardSeenPinsStore: ObservableObject {
    @Published private(set) var seenPinIDs: Set<Int>

    private let storageKey = "whiteboard_seen_pin_ids"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let storedIDs = userDefaults.array(forKey: storageKey) as? [Int] {
            seenPinIDs = Set(storedIDs)
        } else if let storedNumbers = userDefaults.array(forKey: storageKey) as? [NSNumber] {
            seenPinIDs = Set(storedNumbers.map { $0.intValue })
        } else {
            seenPinIDs = []
        }
    }

    func isPinSeen(_ pinID: Int) -> Bool {
        seenPinIDs.contains(pinID)
    }

    func markPinAsSeen(_ pinID: Int) {
        let (inserted, _) = seenPinIDs.insert(pinID)
        if inserted {
            persist()
        }
    }

    func markPinAsSeen(_ pin: WhiteboardPin) {
        markPinAsSeen(pin.id)
    }

    func sync(with pins: [WhiteboardPin]) {
        let activeIDs = Set(pins.map(\.id))
        let obsoleteIDs = seenPinIDs.subtracting(activeIDs)
        guard !obsoleteIDs.isEmpty else { return }

        seenPinIDs.subtract(obsoleteIDs)
        persist()
    }

    private func persist() {
        let idsArray = Array(seenPinIDs).sorted()
        userDefaults.set(idsArray, forKey: storageKey)
    }
}
