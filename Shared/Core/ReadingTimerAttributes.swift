#if os(iOS)
import ActivityKit
import Foundation

struct ReadingTimerAttributes: ActivityAttributes {
    let bookTitle: String
    let bookAuthor: String

    public struct ContentState: Codable, Hashable {

            var startedAt: Date

            var targetSeconds: TimeInterval?

            var elapsedSeconds: TimeInterval

            var dailyTargetMinutes: Int

            var todayTotalSeconds: TimeInterval

            var progressAmount: Double

            var progressUnit: String

            var totalAmount: Double

            var coverData: Data?

        }
}
#endif
