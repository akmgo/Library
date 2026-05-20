#if os(macOS) || os(iOS)
import Foundation

enum ReadingStatsCalculator {
    static func totalDuration(from sessions: [ReadingSession]) -> TimeInterval {
        sessions.reduce(0) { $0 + max($1.duration, 0) }
    }

    static func durationByDay(from sessions: [ReadingSession], calendar: Calendar = .current) -> [Date: TimeInterval] {
        sessions.reduce(into: [:]) { result, session in
            let day = calendar.startOfDay(for: session.startedAt)
            result[day, default: 0] += max(session.duration, 0)
        }
    }

    static func activeReadingDays(from sessions: [ReadingSession], calendar: Calendar = .current) -> Int {
        Set(sessions.map { calendar.startOfDay(for: $0.startedAt) }).count
    }

    static func finishedBookCount(from books: [Book]) -> Int {
        books.filter { $0.status == .finished }.count
    }
}
#endif
