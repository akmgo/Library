#if os(macOS) || os(iOS)
import Foundation
import SwiftData

@Model
final class UserConfig {
    var dailyMinutesGoal: Int = 30
    var yearlyBooksGoal: Int = 20
    var libraryBooksGoal: Int = 100
    var defaultProgressUnit: ProgressUnit = ProgressUnit.page
    var updatedAt: Date = Date()

    init(
        dailyMinutesGoal: Int = 30,
        yearlyBooksGoal: Int = 20,
        libraryBooksGoal: Int = 100,
        defaultProgressUnit: ProgressUnit = .page,
        updatedAt: Date = Date()
    ) {
        self.dailyMinutesGoal = max(dailyMinutesGoal, 0)
        self.yearlyBooksGoal = max(yearlyBooksGoal, 0)
        self.libraryBooksGoal = max(libraryBooksGoal, 0)
        self.defaultProgressUnit = defaultProgressUnit
        self.updatedAt = updatedAt
    }
}
#endif
