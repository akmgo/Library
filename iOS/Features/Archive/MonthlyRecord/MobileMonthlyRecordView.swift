#if os(iOS)
import SwiftData
import SwiftUI

private enum MobileReadingTimelineLayout {
    static let dayGroupSpacing: CGFloat = 34
    static let horizontalInset: CGFloat = 26
    static let monthHeaderBottomSpacing: CGFloat = 14
    static let monthHeaderFontSize: CGFloat = 13
    static let dayTitleFontSize: CGFloat = 24
    static let dayTotalFontSize: CGFloat = 24
    static let dayDividerTopSpacing: CGFloat = 8
    static let dayDividerBottomSpacing: CGFloat = 4
    static let dividerHeight: CGFloat = 1
    static let referenceMinutes: CGFloat = 60
    static let rowSpacing: CGFloat = 2
    static let collapsedVerticalPadding: CGFloat = 4
    static let expandedVerticalPadding: CGFloat = 13
    static let rowTitleFontSize: CGFloat = 16
    static let rowDurationFontSize: CGFloat = 16
    static let rowDurationUnitFontSize: CGFloat = 12
    static let rowDurationMinWidth: CGFloat = 78
    static let detailFontSize: CGFloat = 13
    static let detailHeight: CGFloat = 18
    static let focusLineWidth: CGFloat = 2
    static let focusLineHeight: CGFloat = 13
    static let expansionAnimation = Animation.smooth(duration: 0.22)
}

struct MobileMonthlyRecordView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \ReadingSession.date, order: .reverse) private var sessions: [ReadingSession]
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]

    @State private var expandedSessionIDs: Set<String> = []

    private var readingDays: Int {
        Set(sessions.map { Calendar.current.startOfDay(for: $0.startedAt) }).count
    }

    private var finishedBooksCount: Int {
        books.filter { $0.status == .finished }.count
    }

    private var sections: [MobileReadingTimelineSection] {
        let groups = groupedSessions
        return groups.enumerated().map { index, group in
            let previous = index > 0 ? groups[index - 1] : nil
            let shouldShowMonth = previous == nil
                || !Calendar.current.isDate(group.day, equalTo: previous?.day ?? group.day, toGranularity: .month)
            return MobileReadingTimelineSection(
                group: group,
                monthTitle: shouldShowMonth ? MobileReadingDateText.monthTitle(group.day) : nil
            )
        }
    }

    private var groupedSessions: [MobileReadingDayGroup] {
        let grouped = Dictionary(grouping: sessions) { Calendar.current.startOfDay(for: $0.startedAt) }
        return grouped
            .map { day, sessions in
                MobileReadingDayGroup(
                    day: day,
                    items: sessions
                        .sorted { $0.startedAt > $1.startedAt }
                        .map(MobileReadingSessionItem.init)
                )
            }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        ZStack {
            AppColors.primaryBackground(for: colorScheme).ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: MobileReadingTimelineLayout.dayGroupSpacing) {
                    MobileReadingSummaryView(
                        readingDays: readingDays,
                        finishedBooksCount: finishedBooksCount
                    )

                    if sessions.isEmpty {
                        EmptyStateView(
                            systemImage: "calendar",
                            title: "暂无阅读记录",
                            message: "读完一段后，手动记下时间和页码。",
                            iconSize: 46
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                    } else {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: section.monthTitle == nil ? 0 : MobileReadingTimelineLayout.monthHeaderBottomSpacing) {
                                if let monthTitle = section.monthTitle {
                                    Text(monthTitle)
                                        .font(.system(size: MobileReadingTimelineLayout.monthHeaderFontSize, weight: .semibold))
                                        .foregroundStyle(AppColors.readingAmber.opacity(0.72))
                                }

                                MobileReadingDaySection(
                                    group: section.group,
                                    expandedSessionIDs: $expandedSessionIDs
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, MobileReadingTimelineLayout.horizontalInset)
                .padding(.top, 22)
                .padding(.bottom, AppSpacing.emptyState)
            }
        }
    }
}

private struct MobileReadingSummaryView: View {
    let readingDays: Int
    let finishedBooksCount: Int

    var body: some View {
        HStack(spacing: 10) {
            MobileReadingSummaryMetric(value: readingDays, label: "阅读天数")
            MobileReadingSummaryMetric(value: finishedBooksCount, label: "读完书籍")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

private struct MobileReadingSummaryMetric: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 5) {
            Text("\(value)")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MobileReadingDaySection: View {
    let group: MobileReadingDayGroup
    @Binding var expandedSessionIDs: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: MobileReadingTimelineLayout.dayDividerTopSpacing) {
                HStack(alignment: .center) {
                    Text(group.title)
                        .font(.system(size: MobileReadingTimelineLayout.dayTitleFontSize, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Spacer()

                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text("\(group.minutes)")
                        Text("分钟")
                    }
                    .font(.system(size: MobileReadingTimelineLayout.dayTotalFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.readingAmber)
                    .monospacedDigit()
                }

                MobileReadingDurationDivider(progress: group.durationProgress)
            }
            .padding(.bottom, MobileReadingTimelineLayout.dayDividerBottomSpacing)

            LazyVStack(spacing: MobileReadingTimelineLayout.rowSpacing) {
                ForEach(group.items) { item in
                    MobileReadingPlainRow(
                        item: item,
                        isExpanded: expandedSessionIDs.contains(item.id)
                    ) {
                        withAnimation(MobileReadingTimelineLayout.expansionAnimation) {
                            if expandedSessionIDs.contains(item.id) {
                                expandedSessionIDs.remove(item.id)
                            } else {
                                expandedSessionIDs.insert(item.id)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct MobileReadingDurationDivider: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.primary.opacity(0.86))
                    .frame(height: MobileReadingTimelineLayout.dividerHeight)

                Rectangle()
                    .fill(AppColors.readingAmber.opacity(0.72))
                    .frame(
                        width: progress > 0 ? max(proxy.size.width * min(max(progress, 0), 1), 2) : 0,
                        height: MobileReadingTimelineLayout.dividerHeight
                    )
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: MobileReadingTimelineLayout.dividerHeight)
    }
}

private struct MobileReadingPlainRow: View {
    let item: MobileReadingSessionItem
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 8 : 0) {
            HStack(spacing: 16) {
                Text(item.bookTitle)
                    .font(.system(size: MobileReadingTimelineLayout.rowTitleFontSize, weight: .regular))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("\(item.minutes)")
                        .font(.system(size: MobileReadingTimelineLayout.rowDurationFontSize, weight: .semibold, design: .rounded))
                    Text("分钟")
                        .font(.system(size: MobileReadingTimelineLayout.rowDurationUnitFontSize, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: MobileReadingTimelineLayout.rowDurationMinWidth, alignment: .trailing)
            }

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: MobileReadingTimelineLayout.focusLineWidth / 2, style: .continuous)
                    .fill(AppColors.readingAmber.opacity(0.55))
                    .frame(width: MobileReadingTimelineLayout.focusLineWidth, height: MobileReadingTimelineLayout.focusLineHeight)

                HStack(spacing: 8) {
                    Text(item.pagesCaption)
                    Spacer(minLength: 8)
                    Text(item.timeRangeCaption)
                }
                .font(.system(size: MobileReadingTimelineLayout.detailFontSize, weight: .medium))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
            }
            .frame(height: isExpanded ? MobileReadingTimelineLayout.detailHeight : 0, alignment: .top)
            .clipped()
            .opacity(isExpanded ? 1 : 0)
            .allowsHitTesting(false)
        }
        .padding(.top, MobileReadingTimelineLayout.collapsedVerticalPadding)
        .padding(.bottom, isExpanded ? MobileReadingTimelineLayout.expandedVerticalPadding : MobileReadingTimelineLayout.collapsedVerticalPadding)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

private struct MobileReadingTimelineSection: Identifiable {
    let group: MobileReadingDayGroup
    let monthTitle: String?

    var id: Date { group.day }
}

private struct MobileReadingDayGroup: Identifiable {
    let day: Date
    let items: [MobileReadingSessionItem]

    var id: Date { day }

    var title: String {
        if Calendar.current.isDateInToday(day) { return "今天" }
        if Calendar.current.isDateInYesterday(day) { return "昨天" }
        return MobileReadingDateText.monthDay(day)
    }

    var minutes: Int {
        items.reduce(0) { $0 + $1.minutes }
    }

    var durationProgress: CGFloat {
        CGFloat(minutes) / MobileReadingTimelineLayout.referenceMinutes
    }
}

private struct MobileReadingSessionItem: Identifiable {
    let session: ReadingSession

    var id: String { session.id }
    var bookTitle: String { session.book?.title ?? "未知书籍" }
    var minutes: Int { max(Int(session.duration / 60), 0) }

    var pagesCaption: String {
        let delta = max(session.deltaAmount, 0)
        if delta > 0, session.endAmount > 0 {
            return "读了 \(Int(delta)) 页，至第 \(Int(session.endAmount)) 页"
        }
        if delta > 0 {
            return "读了 \(Int(delta)) 页"
        }
        if session.endAmount > 0 {
            return "读到第 \(Int(session.endAmount)) 页"
        }
        return "未记录页码"
    }

    var timeRangeCaption: String {
        "\(MobileReadingDateText.time(session.startedAt))-\(MobileReadingDateText.time(session.endedAt))"
    }
}

private enum MobileReadingDateText {
    static func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    static func monthDay(_ date: Date) -> String {
        AppFormatters.chineseShortDateFormatter.string(from: date)
    }

    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#if DEBUG
#Preview("记录") {
    PreviewWithData {
        MobileMonthlyRecordView()
    }
}
#endif

#endif
