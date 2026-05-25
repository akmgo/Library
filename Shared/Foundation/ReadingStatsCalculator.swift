#if os(macOS) || os(iOS)
import Foundation
import SwiftUI

enum BookGallerySortKey: CaseIterable {
    case newest
    case oldest
    case titleAscending
    case lastRead
    case dateAdded
    case progress
    case title

    var displayName: String {
        switch self {
        case .newest: return "最新加入"
        case .oldest: return "最早加入"
        case .titleAscending: return "标题 A-Z"
        case .lastRead: return "最近阅读"
        case .dateAdded: return "添加时间"
        case .progress: return "阅读进度"
        case .title: return "书名"
        }
    }
}

enum ExcerptGallerySortKey {
    case newest
    case oldest
    case titleAscending
}

enum AnnotationSortKey {
    case newest
    case oldest
    case bookTitle
}

struct ExcerptListItem: Identifiable, Hashable {
    let id: String
    let content: String
    let date: Date
    let bookTitle: String
    let bookAuthor: String
    let bookID: String
    let isNote: Bool
    let category: ExcerptCategory
    let title: String?
    let sourceAuthor: String?
    let source: String?
    let coverData: Data?

    var isBookBound: Bool { !bookID.isEmpty }
    var bookDisplayTitle: String { Self.nonEmpty(bookTitle) ?? "未关联书籍" }
    var bookDisplayAuthor: String { Self.nonEmpty(bookAuthor) ?? "佚名" }
    var sourceTitleDisplay: String {
        Self.nonEmpty(title)
            ?? Self.nonEmpty(source)
            ?? (isBookBound ? bookDisplayTitle : category.displayName)
    }
    var sourceAuthorDisplay: String {
        Self.nonEmpty(sourceAuthor)
            ?? (isBookBound ? bookDisplayAuthor : "佚名")
    }
    var sourceDisplay: String {
        Self.nonEmpty(source)
            ?? sourceTitleDisplay
    }
    var sortTitle: String {
        isBookBound ? bookDisplayTitle : sourceTitleDisplay
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

enum ReadingStatsCalculator {
    struct BookGallerySnapshot {
        let books: [Book]
        let totalInventoryCount: Int
        let inventoryPoints: [InventoryDataPoint]

        static let empty = BookGallerySnapshot(
            books: [],
            totalInventoryCount: 0,
            inventoryPoints: []
        )
    }

    struct ExcerptGalleryStats {
        let total: Int
        let poetry: Int
        let lyric: Int
        let prose: Int
        let quote: Int
        let movie: Int
        let web: Int

        var poetryAndLyric: Int { poetry + lyric }

        static let empty = ExcerptGalleryStats(
            total: 0,
            poetry: 0,
            lyric: 0,
            prose: 0,
            quote: 0,
            movie: 0,
            web: 0
        )
    }

    struct ExcerptGallerySnapshot {
        let excerpts: [Excerpt]
        let stats: ExcerptGalleryStats

        static let empty = ExcerptGallerySnapshot(excerpts: [], stats: .empty)
    }

    struct InspirationSnapshot {
        let excerpts: [ExcerptListItem]
        let totalContentCharacters: Int
        let uniqueBooksCount: Int

        static let empty = InspirationSnapshot(
            excerpts: [],
            totalContentCharacters: 0,
            uniqueBooksCount: 0
        )
    }

    struct DashboardSnapshot {
        let activeReadingBook: Book?
        let yearlyCount: Int
        let monthlyDays: Int
        let weekCount: Int
        let todayMinutes: Int
        let totalFinished: Int
        let totalLibrary: Int
        let momentumPoints: [MomentumDataPoint]
        let momentumTotal: Int
        let heatmapColumns: [[HeatmapDataPoint]]
        let heatmapActiveDays: Int
        let resonancePoints: [ResonanceDataPoint]
        let queueBooks: [Book]
        let spectrumPoints: [SpectrumDataPoint]

        static let empty = DashboardSnapshot(
            activeReadingBook: nil,
            yearlyCount: 0,
            monthlyDays: 0,
            weekCount: 0,
            todayMinutes: 0,
            totalFinished: 0,
            totalLibrary: 0,
            momentumPoints: [],
            momentumTotal: 0,
            heatmapColumns: [],
            heatmapActiveDays: 0,
            resonancePoints: [],
            queueBooks: [],
            spectrumPoints: []
        )
    }

    struct YearlyArchiveSnapshot {
        let availableYears: [Int]
        let books: [Book]
        let totalDaysRead: Int
        let totalReadingHours: Int
        let longestStreak: Int
    }

    struct ReadingMonthSection: Identifiable {
        let id: String
        let year: Int
        let month: Int
        let days: [Date?]
    }

    struct MonthlyArchiveSnapshot {
        let durationByDay: [Date: TimeInterval]
        let sections: [ReadingMonthSection]
        let currentMonthID: String
    }

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

    static func bookGallerySnapshot(
        books: [Book],
        filterStatus: BookStatus?,
        searchText: String,
        sortKey: BookGallerySortKey,
        ascending: Bool? = nil
    ) -> BookGallerySnapshot {
        let totalCount = books.count
        let counts = Dictionary(grouping: books, by: \.status).mapValues(\.count)
        let rawStats: [(label: String, count: Int, color: Color)] = [
            ("已读", counts[.finished, default: 0], .indigo),
            ("在读", counts[.reading, default: 0], .blue),
            ("未读", counts[.unread, default: 0], .gray),
            ("想读", counts[.planned, default: 0], .orange),
            ("弃读", counts[.abandoned, default: 0], .red)
        ]
        let inventoryPoints = totalCount > 0
            ? rawStats.filter { $0.count > 0 }.map {
                InventoryDataPoint(
                    label: $0.label,
                    count: $0.count,
                    color: $0.color,
                    percentage: Double($0.count) / Double(totalCount)
                )
            }
            : []

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var displayBooks = books.filter { book in
            guard filterStatus == nil || book.status == filterStatus else { return false }
            guard !query.isEmpty else { return true }
            return book.title.lowercased().contains(query)
                || book.author.lowercased().contains(query)
                || book.tags.contains { $0.lowercased().contains(query) }
        }

        displayBooks.sort { lhs, rhs in
            let isOrderedAscending: Bool
            switch sortKey {
            case .newest, .dateAdded:
                isOrderedAscending = lhs.createdAt < rhs.createdAt
            case .oldest:
                isOrderedAscending = lhs.createdAt < rhs.createdAt
            case .titleAscending, .title:
                isOrderedAscending = lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            case .lastRead:
                let lhsDate = lhs.lastReadAt ?? lhs.startDate ?? lhs.createdAt
                let rhsDate = rhs.lastReadAt ?? rhs.startDate ?? rhs.createdAt
                isOrderedAscending = lhsDate < rhsDate
            case .progress:
                isOrderedAscending = lhs.progressRatio < rhs.progressRatio
            }

            let shouldAscend = ascending ?? {
                switch sortKey {
                case .oldest, .titleAscending, .title:
                    return true
                default:
                    return false
                }
            }()
            return shouldAscend ? isOrderedAscending : !isOrderedAscending
        }

        return BookGallerySnapshot(
            books: displayBooks,
            totalInventoryCount: totalCount,
            inventoryPoints: inventoryPoints
        )
    }

    static func excerptGallerySnapshot(
        excerpts: [Excerpt],
        category: ExcerptCategory?,
        searchText: String,
        sortKey: ExcerptGallerySortKey
    ) -> ExcerptGallerySnapshot {
        let stats = ExcerptGalleryStats(
            total: excerpts.count,
            poetry: excerpts.filter { $0.category == .poetry }.count,
            lyric: excerpts.filter { $0.category == .lyric }.count,
            prose: excerpts.filter { $0.category == .prose }.count,
            quote: excerpts.filter { $0.category == .quote }.count,
            movie: excerpts.filter { $0.category == .movie }.count,
            web: excerpts.filter { $0.category == .web }.count
        )

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var displayExcerpts = excerpts.filter { excerpt in
            guard category == nil || excerpt.category == category else { return false }
            guard !query.isEmpty else { return true }
            return (excerpt.title ?? "").lowercased().contains(query)
                || excerpt.author.lowercased().contains(query)
                || excerpt.dynasty.lowercased().contains(query)
                || excerpt.content.lowercased().contains(query)
                || excerpt.annotation.lowercased().contains(query)
        }

        switch sortKey {
        case .newest:
            displayExcerpts.sort { $0.addedDate > $1.addedDate }
        case .oldest:
            displayExcerpts.sort { $0.addedDate < $1.addedDate }
        case .titleAscending:
            displayExcerpts.sort { ($0.title ?? "").localizedStandardCompare($1.title ?? "") == .orderedAscending }
        }

        return ExcerptGallerySnapshot(excerpts: displayExcerpts, stats: stats)
    }

    static func inspirationSnapshot(
        excerpts: [Excerpt],
        type: ExcerptCategory?,
        searchText: String,
        sortKey: AnnotationSortKey,
        randomize: Bool
    ) -> InspirationSnapshot {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var excerpts = excerpts.compactMap { excerpt -> ExcerptListItem? in
            guard type == nil || excerpt.category == type else { return nil }

            let bookTitle = excerpt.book?.title ?? ""
            let bookAuthor = excerpt.book?.author ?? ""
            if !query.isEmpty {
                let matches = excerpt.content.lowercased().contains(query)
                    || bookTitle.lowercased().contains(query)
                    || bookAuthor.lowercased().contains(query)
                    || excerpt.category.displayName.lowercased().contains(query)
                    || (excerpt.title ?? "").lowercased().contains(query)
                    || (excerpt.sourceAuthor ?? "").lowercased().contains(query)
                    || (excerpt.source ?? "").lowercased().contains(query)
                guard matches else { return nil }
            }

            return ExcerptListItem(
                id: excerpt.id,
                content: excerpt.content,
                date: excerpt.createdAt,
                bookTitle: bookTitle,
                bookAuthor: bookAuthor,
                bookID: excerpt.book?.id ?? "",
                isNote: excerpt.isNote,
                category: excerpt.category,
                title: excerpt.title,
                sourceAuthor: excerpt.sourceAuthor,
                source: excerpt.source,
                coverData: excerpt.book?.coverData
            )
        }

        switch sortKey {
        case .newest:
            excerpts.sort { $0.date > $1.date }
        case .oldest:
            excerpts.sort { $0.date < $1.date }
        case .bookTitle:
            excerpts.sort { $0.sortTitle.localizedStandardCompare($1.sortTitle) == .orderedAscending }
        }

        if randomize {
            excerpts.shuffle()
        }

        return InspirationSnapshot(
            excerpts: excerpts,
            totalContentCharacters: excerpts.reduce(0) { $0 + $1.content.count },
            uniqueBooksCount: Set(excerpts.map(\.bookID)).filter { !$0.isEmpty }.count
        )
    }

    static func dashboardSnapshot(
        books: [Book],
        sessions: [ReadingSession],
        excerpts: [Excerpt],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> DashboardSnapshot {
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: today)) ?? today
        let currentYearSessions = sessions.filter { $0.date >= yearStart }
        let finishedBooks = books.filter { $0.status == .finished }
        let currentYear = calendar.component(.year, from: today)

        let yearlyCount = finishedBooks.filter { book in
            guard let finishDate = book.finishDate else { return false }
            return calendar.component(.year, from: finishDate) == currentYear
        }.count

        let monthlyDays = Set(currentYearSessions.filter {
            calendar.isDate($0.date, equalTo: today, toGranularity: .month)
        }.map {
            calendar.startOfDay(for: $0.date)
        }).count

        let weekCount = Set(currentYearSessions.filter {
            calendar.isDate($0.date, equalTo: today, toGranularity: .weekOfYear)
        }.map {
            calendar.startOfDay(for: $0.date)
        }).count

        let todayMinutes = currentYearSessions.filter {
            calendar.isDate($0.date, inSameDayAs: today)
        }.reduce(0) {
            $0 + Int(max($1.duration, 0))
        } / 60

        let momentum = momentumData(from: sessions, endingAt: today, calendar: calendar)
        let heatmap = yearlyHeatmap(from: sessions, endingAt: today, calendar: calendar)

        return DashboardSnapshot(
            activeReadingBook: activeReadingBook(from: books),
            yearlyCount: yearlyCount,
            monthlyDays: monthlyDays,
            weekCount: weekCount,
            todayMinutes: todayMinutes,
            totalFinished: finishedBooks.count,
            totalLibrary: books.count,
            momentumPoints: momentum.points,
            momentumTotal: momentum.totalMinutes,
            heatmapColumns: heatmap.columns,
            heatmapActiveDays: heatmap.activeDays,
            resonancePoints: resonanceData(from: excerpts),
            queueBooks: queueBooks(from: books),
            spectrumPoints: spectrumData(from: books)
        )
    }

    static func yearlyArchiveSnapshot(
        books: [Book],
        sessions: [ReadingSession],
        selectedYear: Int,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> YearlyArchiveSnapshot {
        var years = Set(books.compactMap { book -> Int? in
            guard book.status == .finished, let finishDate = book.finishDate else { return nil }
            return calendar.component(.year, from: finishDate)
        })
        years.insert(calendar.component(.year, from: today))

        let yearlyBooks = books.filter { book in
            guard book.status == .finished, let finishDate = book.finishDate else { return false }
            return calendar.component(.year, from: finishDate) == selectedYear
        }.sorted {
            ($0.finishDate ?? .distantPast) > ($1.finishDate ?? .distantPast)
        }

        let yearSessions = sessions.filter {
            calendar.component(.year, from: $0.date) == selectedYear
        }
        let uniqueDays = Set(yearSessions.map { calendar.startOfDay(for: $0.date) }).sorted()

        return YearlyArchiveSnapshot(
            availableYears: Array(years).sorted(by: >),
            books: yearlyBooks,
            totalDaysRead: uniqueDays.count,
            totalReadingHours: Int(totalDuration(from: yearSessions) / 3600),
            longestStreak: longestStreak(in: uniqueDays, calendar: calendar)
        )
    }

    static func monthlyArchiveSnapshot(
        sessions: [ReadingSession],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> MonthlyArchiveSnapshot {
        let durations = durationByDay(from: sessions, calendar: calendar)
        let fallbackStart = calendar.date(byAdding: .month, value: -6, to: today) ?? today
        let earliestDate = sessions.map(\.date).min() ?? fallbackStart
        let startMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: earliestDate)) ?? earliestDate
        let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        let endMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth

        var sections: [ReadingMonthSection] = []
        var cursor = startMonth
        while cursor <= endMonth {
            let year = calendar.component(.year, from: cursor)
            let month = calendar.component(.month, from: cursor)
            sections.append(
                ReadingMonthSection(
                    id: String(format: "%d-%02d", year, month),
                    year: year,
                    month: month,
                    days: daysInMonth(containing: cursor, calendar: calendar)
                )
            )
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: cursor) else {
                break
            }
            cursor = nextMonth
        }

        return MonthlyArchiveSnapshot(
            durationByDay: durations,
            sections: sections,
            currentMonthID: String(
                format: "%d-%02d",
                calendar.component(.year, from: today),
                calendar.component(.month, from: today)
            )
        )
    }

    static func momentumData(
        from sessions: [ReadingSession],
        endingAt endDate: Date = Date(),
        dayCount: Int = 14,
        calendar: Calendar = .current
    ) -> (points: [MomentumDataPoint], totalMinutes: Int) {
        let today = calendar.startOfDay(for: endDate)
        let days = ReadingDateHelper.daysEnding(at: today, count: dayCount, calendar: calendar)
        let daySet = Set(days)
        let durations = durationByDay(from: sessions, calendar: calendar)
            .filter { daySet.contains($0.key) }

        let points = days.map { day in
            MomentumDataPoint(
                date: day,
                minutes: (durations[day] ?? 0) / 60,
                isToday: calendar.isDate(day, inSameDayAs: today)
            )
        }

        let totalMinutes = Int(durations.values.reduce(0, +) / 60)
        return (points, totalMinutes)
    }

    static func yearlyHeatmap(
        from sessions: [ReadingSession],
        endingAt endDate: Date = Date(),
        weekCount: Int = 53,
        calendar baseCalendar: Calendar = .current
    ) -> (columns: [[HeatmapDataPoint]], activeDays: Int) {
        var calendar = baseCalendar
        calendar.firstWeekday = 2

        let today = calendar.startOfDay(for: endDate)
        let daysToSubtract = (calendar.component(.weekday, from: today) + 5) % 7
        let currentWeekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) ?? today
        let startDate = calendar.date(byAdding: .weekOfYear, value: -(weekCount - 1), to: currentWeekStart) ?? currentWeekStart
        let durations = durationByDay(from: sessions, calendar: calendar)

        var activeDays = 0
        let columns = (0..<weekCount).map { weekIndex in
            (0..<7).map { dayIndex in
                let date = calendar.date(byAdding: .day, value: weekIndex * 7 + dayIndex, to: startDate) ?? startDate
                let duration = durations[date] ?? 0
                let minutes = Int(duration / 60)
                let isFuture = date > today
                let intensity = !isFuture && minutes > 0 ? VisualEngines.ReadingHeatmap.intensity(for: minutes) : 0
                if !isFuture && minutes > 0 {
                    activeDays += 1
                }

                let dateString = date.formatted(.dateTime.month().day())
                let tooltip = isFuture ? "未到" : (minutes == 0 ? "\(dateString): 未打卡" : "\(dateString): 专注 \(minutes) 分钟")
                return HeatmapDataPoint(
                    date: date,
                    minutes: minutes,
                    intensity: intensity,
                    isFuture: isFuture,
                    tooltip: tooltip
                )
            }
        }

        return (columns, activeDays)
    }

    static func activeReadingBook(from books: [Book]) -> Book? {
        books.filter { $0.status == .reading }.max {
            let lhs = $0.lastReadAt ?? $0.startDate ?? $0.createdAt
            let rhs = $1.lastReadAt ?? $1.startDate ?? $1.createdAt
            return lhs < rhs
        }
    }

    static func queueBooks(from books: [Book], limit: Int = 4) -> [Book] {
        Array(books.filter { $0.status == .planned }.prefix(limit))
    }

    static func resonanceData(from excerpts: [Excerpt], limit: Int = 100) -> [ResonanceDataPoint] {
        let excerpts = excerpts
            .filter { $0.category == .bookExcerpt }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)

        return excerpts.map {
            ResonanceDataPoint(content: $0.content, source: $0.book?.title ?? "札记")
        }.shuffled()
    }

    static func spectrumData(from books: [Book], limit: Int = 5) -> [SpectrumDataPoint] {
        let finishedBooks = books.filter { $0.status == .finished }
        var counts: [String: Double] = [:]
        for book in finishedBooks {
            for tag in book.tags {
                counts[tag, default: 0] += 1
            }
        }

        let topTags = counts.sorted { $0.value > $1.value }.prefix(limit)
        let total = topTags.reduce(0.0) { $0 + $1.value }
        guard total > 0 else { return [] }

        let colors: [Color] = [.purple, .indigo, .teal, .orange, .blue]
        return topTags.enumerated().map { index, element in
            SpectrumDataPoint(
                tagName: element.key,
                percentage: (element.value / total) * 100,
                color: colors[index % colors.count]
            )
        }
    }

    static func longestStreak(in sortedDays: [Date], calendar: Calendar = .current) -> Int {
        var maxStreak = 0
        var currentStreak = 0
        var previousDate: Date?

        for date in sortedDays {
            if let previousDate {
                let diff = calendar.dateComponents([.day], from: previousDate, to: date).day ?? 0
                currentStreak = diff == 1 ? currentStreak + 1 : 1
            } else {
                currentStreak = 1
            }

            maxStreak = max(maxStreak, currentStreak)
            previousDate = date
        }

        return maxStreak
    }

    static func daysInMonth(containing date: Date, calendar: Calendar = .current) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        else {
            return []
        }

        let weekday = calendar.component(.weekday, from: firstDay)
        let offset = (weekday + 5) % 7
        var days: [Date?] = Array(repeating: nil, count: offset)
        for index in 0..<range.count {
            days.append(calendar.date(byAdding: .day, value: index, to: firstDay))
        }
        return days
    }
}
#endif
