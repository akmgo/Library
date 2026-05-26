#if os(macOS) || os(iOS)
internal import Combine
import Foundation

@MainActor
final class ReadingTimerStore: ObservableObject {
    static let shared = ReadingTimerStore()

    @Published private(set) var activeBookID: String?
    @Published private(set) var startedAt: Date?
    @Published private(set) var targetDuration: TimeInterval?

    private init() {}

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
    }

    func startTimed(bookID: String, duration: TimeInterval, at date: Date = Date()) {
        activeBookID = bookID
        startedAt = date
        targetDuration = duration
    }

    func cancel() {
        activeBookID = nil
        startedAt = nil
        targetDuration = nil
    }

    func startedAt(for bookID: String) -> Date? {
        activeBookID == bookID ? startedAt : nil
    }

    func elapsedSeconds(for bookID: String, now: Date = Date()) -> TimeInterval {
        guard let startedAt = startedAt(for: bookID) else { return 0 }
        return max(now.timeIntervalSince(startedAt), 0)
    }
}
#endif
