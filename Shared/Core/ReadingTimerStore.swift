#if os(macOS) || os(iOS)
internal import Combine
import Foundation

@MainActor
final class ReadingTimerStore: ObservableObject {
    static let shared = ReadingTimerStore()

    @Published private(set) var activeBookID: String?
    @Published private(set) var startedAt: Date?
    @Published private(set) var targetDuration: TimeInterval?

    private let defaults = SharedDatabase.shared.sharedDefaults

    private init() {
        restoreFromDefaults()
    }

    var isActive: Bool {
        activeBookID != nil && startedAt != nil
    }

    func isTiming(bookID: String) -> Bool {
        activeBookID == bookID && startedAt != nil
    }

    func start(bookID: String, at date: Date = Date()) {
        activeBookID = bookID
        startedAt = date
        targetDuration = nil
        persistToDefaults()
    }

    func startTimed(bookID: String, duration: TimeInterval, at date: Date = Date()) {
        activeBookID = bookID
        startedAt = date
        targetDuration = duration
        persistToDefaults()
    }

    func cancel() {
        activeBookID = nil
        startedAt = nil
        targetDuration = nil
        clearDefaults()
    }

    func syncFromDefaults() {
        guard let bookID = defaults.string(forKey: .activeTimerBookIDKey),
              let startedAt = defaults.object(forKey: .activeTimerStartedAtKey) as? Date else {
            return
        }
        if activeBookID != bookID || self.startedAt != startedAt {
            activeBookID = bookID
            self.startedAt = startedAt
            targetDuration = defaults.object(forKey: .activeTimerTargetDurationKey) as? TimeInterval
        }
    }

    func startedAt(for bookID: String) -> Date? {
        activeBookID == bookID ? startedAt : nil
    }

    func elapsedSeconds(for bookID: String, now: Date = Date()) -> TimeInterval {
        guard let startedAt = startedAt(for: bookID) else { return 0 }
        return max(now.timeIntervalSince(startedAt), 0)
    }

    // MARK: - App Group Persistence

    private func persistToDefaults() {
        guard let bookID = activeBookID, let startedAt else { return }
        defaults.set(bookID, forKey: .activeTimerBookIDKey)
        defaults.set(startedAt, forKey: .activeTimerStartedAtKey)
        if let targetDuration {
            defaults.set(targetDuration, forKey: .activeTimerTargetDurationKey)
        } else {
            defaults.removeObject(forKey: .activeTimerTargetDurationKey)
        }
    }

    private func clearDefaults() {
        defaults.removeObject(forKey: .activeTimerBookIDKey)
        defaults.removeObject(forKey: .activeTimerStartedAtKey)
        defaults.removeObject(forKey: .activeTimerTargetDurationKey)
    }

    private func restoreFromDefaults() {
        guard let bookID = defaults.string(forKey: .activeTimerBookIDKey),
              let startedAt = defaults.object(forKey: .activeTimerStartedAtKey) as? Date else {
            return
        }
        activeBookID = bookID
        self.startedAt = startedAt
        targetDuration = defaults.object(forKey: .activeTimerTargetDurationKey) as? TimeInterval
    }
}

private extension String {
    static let activeTimerBookIDKey = "com.akram.library.activeTimerBookID"
    static let activeTimerStartedAtKey = "com.akram.library.activeTimerStartedAt"
    static let activeTimerTargetDurationKey = "com.akram.library.activeTimerTargetDuration"
}
#endif
