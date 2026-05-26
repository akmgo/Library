#if os(macOS) || os(iOS)
import Foundation
import SwiftData

@Model
final class ReadingSession {
    var id: String = UUID().uuidString
    var date: Date = Calendar.current.startOfDay(for: Date())
    var inputMode: ReadingInputMode = ReadingInputMode.manual

    var startedAt: Date = Date()
    var endedAt: Date = Date()
    var duration: TimeInterval = 0

    var progressUnit: ProgressUnit = ProgressUnit.page
    var startAmount: Double = 0
    var endAmount: Double = 0

    var createdAt: Date = Date()
    var book: Book?

    init(
        date: Date? = nil,
        inputMode: ReadingInputMode = .manual,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        duration: TimeInterval? = nil,
        progressUnit: ProgressUnit = .page,
        startAmount: Double = 0,
        endAmount: Double = 0,
        createdAt: Date = Date(),
        book: Book? = nil
    ) {
        let resolvedDuration = max(duration ?? endedAt?.timeIntervalSince(startedAt) ?? 0, 0)
        let resolvedEnd = endedAt ?? startedAt.addingTimeInterval(resolvedDuration)

        self.startedAt = startedAt
        self.endedAt = resolvedEnd
        self.duration = max(resolvedEnd.timeIntervalSince(startedAt), resolvedDuration)
        self.date = Calendar.current.startOfDay(for: date ?? startedAt)
        self.inputMode = inputMode
        self.progressUnit = progressUnit
        self.startAmount = max(startAmount, 0)
        self.endAmount = max(endAmount, 0)
        self.createdAt = createdAt
        self.book = book
    }

    var deltaAmount: Double {
        endAmount - startAmount
    }

    var displayDuration: String {
        let minutes = Int(duration / 60)
        if minutes < 60 { return "\(minutes) 分钟" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) 小时" : "\(hours) 小时 \(remainder) 分钟"
    }

    var displayTimeRange: String {
        "\(startedAt.formatted(date: .omitted, time: .shortened)) - \(endedAt.formatted(date: .omitted, time: .shortened))"
    }

    var displayDelta: String {
        let amount = max(deltaAmount, 0)
        switch progressUnit {
        case .page: return "\(Int(amount)) 页"
        case .percent: return "\(Int(amount))%"
        case .chapter: return "\(Int(amount)) 章"
        }
    }
}
#endif
