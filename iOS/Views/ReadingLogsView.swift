import SwiftData
import SwiftUI

private enum ReadingLogsLayout {
    // 不同日期分组之间的间距，决定时间线一级分割的呼吸感。
    static let dayGroupSpacing: CGFloat = 34

    // 记录时间线区域额外左右内缩，增加页面呼吸感。
    static let timelineHorizontalInset: CGFloat = 8

    // 月份标题和其下方第一个日期组之间的间距。
    static let monthHeaderBottomSpacing: CGFloat = 14

    // 月份标题字号。
    static let monthHeaderFontSize: CGFloat = 13

    // 月份标题顶部额外留白。
    static let monthHeaderTopPadding: CGFloat = 2

    // 日期行文字大小，日期是时间线的一级重点。
    static let dayTitleFontSize: CGFloat = 24

    // 日期行和记录行之间的上下间距。
    static let dayHeaderToRecordsSpacing: CGFloat = 4

    // 日期行右侧当天总时长数字大小。
    static let dayTotalMinutesFontSize: CGFloat = 24

    // 日期行右侧“分钟”单位大小。
    static let dayTotalUnitFontSize: CGFloat = 24

    // 日期行右侧数字和“分钟”之间的间距。
    static let dayTotalUnitSpacing: CGFloat = 2

    // 日期行和时长参考分割线之间的间距。
    static let dayDurationDividerTopSpacing: CGFloat = 8

    // 日期时长参考分割线和记录行之间的间距。
    static let dayDurationDividerBottomSpacing: CGFloat = 4

    // 日期时长参考分割线底线高度，先作为细分割线存在。
    static let dayDurationDividerTrackHeight: CGFloat = 1

    // 日期时长参考分割线填充线高度，保持足够克制。
    static let dayDurationDividerFillHeight: CGFloat = 1

    // 日期时长参考分割线圆角。
    static let dayDurationDividerRadius: CGFloat = 1

    // 日期时长参考分割线最小填充宽度，避免短记录完全不可见。
    static let dayDurationDividerMinimumFillWidth: CGFloat = 2

    // 日期时长参考刻度分钟数，只用于显示比例，不是目标系统。
    static let dayDurationReferenceMinutes: CGFloat = 60

    // 顶部两个数据之间的水平间距。
    static let summaryMetricSpacing: CGFloat = 10

    // 顶部数据区域的上下留白。
    static let summaryVerticalPadding: CGFloat = 10

    // 顶部数据数字大小。
    static let summaryValueFontSize: CGFloat = 34

    // 顶部数据标签大小。
    static let summaryLabelFontSize: CGFloat = 13

    // 顶部数据数字和标签之间的上下间距。
    static let summaryContentSpacing: CGFloat = 5

    // 同一天内不同阅读记录之间的上下间距。
    static let recordRowSpacing: CGFloat = 2

    // 阅读记录默认单行状态的上下内边距。
    static let recordCollapsedVerticalPadding: CGFloat = 4

    // 阅读记录展开状态的上下内边距。
    static let recordExpandedVerticalPadding: CGFloat = 13

    // 阅读记录主行左侧书名和右侧时长之间的间距。
    static let recordHorizontalSpacing: CGFloat = 16

    // 阅读记录书名字号。
    static let recordTitleFontSize: CGFloat = 16

    // 阅读记录时长数字和“分钟”的字号，保持和书名一致。
    static let recordDurationFontSize: CGFloat = 16

    // 阅读记录时长单位字号，让“分钟”落在数字右下角。
    static let recordDurationUnitFontSize: CGFloat = 12

    // 阅读记录时长数字和“分钟”之间的间距。
    static let recordDurationUnitSpacing: CGFloat = 3

    // 阅读记录右侧时长区域最小宽度。
    static let recordDurationMinWidth: CGFloat = 78

    // 阅读记录展开时左侧聚焦竖线宽度。
    static let recordFocusLineWidth: CGFloat = 2

    // 阅读记录左侧聚焦竖线和内容之间的间距。
    static let recordFocusLineSpacing: CGFloat = 8

    // 阅读记录展开聚焦竖线高度，和详情文字内容对齐。
    static let recordFocusLineHeight: CGFloat = 13

    // 阅读记录展开后，主行和详情行之间的间距。
    static let recordSummaryToDetailSpacing: CGFloat = 8

    // 阅读记录详情行字号。
    static let recordDetailFontSize: CGFloat = 13

    // 阅读记录详情行展开后的固定高度，用于稳定滑动展开动画。
    static let recordDetailHeight: CGFloat = 18

    // 阅读记录详情行内部元素间距。
    static let recordDetailSpacing: CGFloat = 8

    // 阅读记录展开和收起动画时长。
    static let recordExpansionDuration: Double = 0.22

    // 阅读记录展开和收起的统一动画，必须同时驱动当前行和下方行的布局变化。
    static let recordExpansionAnimation = Animation.smooth(duration: recordExpansionDuration)

    // 详情页复用记录行的横向间距。
    static let detailRowHorizontalSpacing: CGFloat = 14

    // 详情页复用记录行左侧日期数字和月份之间的间距。
    static let detailRowDateSpacing: CGFloat = 2

    // 详情页复用记录行左侧日期列宽度。
    static let detailRowDateColumnWidth: CGFloat = 48

    // 详情页复用记录行左侧日期数字大小。
    static let detailRowDateDayFontSize: CGFloat = 24

    // 详情页复用记录行左侧月份文字大小。
    static let detailRowDateMonthFontSize: CGFloat = 12

    // 详情页复用记录行书名和辅助信息之间的间距。
    static let detailRowContentSpacing: CGFloat = 5

    // 详情页复用记录行书名字号。
    static let detailRowTitleFontSize: CGFloat = 17

    // 详情页复用记录行辅助信息内部间距。
    static let detailRowMetaSpacing: CGFloat = 8

    // 详情页复用记录行辅助信息字号。
    static let detailRowMetaFontSize: CGFloat = 14

    // 详情页复用记录行右侧箭头大小。
    static let detailRowChevronFontSize: CGFloat = 12

    // 详情页复用记录行水平内边距。
    static let detailRowHorizontalPadding: CGFloat = 16

    // 详情页复用记录行上下内边距。
    static let detailRowVerticalPadding: CGFloat = 14
}

struct ReadingLogsView: View {
    @Environment(\.modelContext) private var modelContext

    let books: [Book]
    let logs: [ReadingLog]

    @State private var expandedLogIDs: Set<UUID> = []
    @State private var editingLog: ReadingLog?
    @State private var deletingLog: ReadingLog?

    private var readingDays: Int {
        Set(logs.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    private var finishedBooksCount: Int {
        books.filter { $0.status == .finished }.count
    }

    private var groupedLogs: [LogDayGroup] {
        let pagesReadByLogID = ReadingLogMetrics.pagesReadByLogID(for: logs)
        let items = logs.map { log in
            ReadingLogDisplayItem(log: log, pagesRead: pagesReadByLogID[log.id])
        }
        let groups = Dictionary(grouping: items) { Calendar.current.startOfDay(for: $0.log.date) }
        return groups
            .map { day, items in
                LogDayGroup(day: day, items: items.sorted { $0.log.date > $1.log.date })
            }
            .sorted { $0.day > $1.day }
    }

    private var timelineSections: [LogTimelineSection] {
        let groups = groupedLogs
        return groups.enumerated().map { index, group in
            let previousGroup = index > 0 ? groups[index - 1] : nil
            let shouldShowMonth = previousGroup == nil
                || !Calendar.current.isDate(group.day, equalTo: previousGroup?.day ?? group.day, toGranularity: .month)
            return LogTimelineSection(
                group: group,
                monthTitle: shouldShowMonth ? AppDateText.monthTitle(group.day) : nil
            )
        }
    }

    var body: some View {
        PageShell {
            ReadingLogSummaryView(
                readingDays: readingDays,
                finishedBooksCount: finishedBooksCount
            )

            if logs.isEmpty {
                AppEmptyState(
                    title: "暂无阅读记录",
                    message: "读完一段后，手动记下时间和页码。",
                    systemImage: "calendar"
                )
            } else {
                LazyVStack(alignment: .leading, spacing: ReadingLogsLayout.dayGroupSpacing) {
                    ForEach(timelineSections) { section in
                        VStack(alignment: .leading, spacing: section.monthTitle == nil ? 0 : ReadingLogsLayout.monthHeaderBottomSpacing) {
                            if let monthTitle = section.monthTitle {
                                ReadingLogMonthHeader(title: monthTitle)
                            }

                            ReadingLogDaySection(
                                group: section.group,
                                expandedLogIDs: $expandedLogIDs,
                                onEdit: { editingLog = $0 },
                                onDelete: { deletingLog = $0 }
                            )
                        }
                    }
                }
                .padding(.horizontal, ReadingLogsLayout.timelineHorizontalInset)
                .transition(.opacity)
            }
        }
        .sheet(item: $editingLog) { log in
            AddReadingLogSheet(books: books, preferredBookID: log.book?.id, editingLog: log)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "删除这条阅读记录？",
            isPresented: Binding(
                get: { deletingLog != nil },
                set: { if !$0 { deletingLog = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let deletingLog {
                    delete(deletingLog)
                }
                deletingLog = nil
            }
            Button("取消", role: .cancel) {
                deletingLog = nil
            }
        }
    }

    private func delete(_ log: ReadingLog) {
        let book = log.book
        modelContext.delete(log)
        ReadingLogMetrics.refreshCurrentPage(for: book, excluding: log.id)
        try? modelContext.save()
    }
}

private struct ReadingLogSummaryView: View {
    let readingDays: Int
    let finishedBooksCount: Int

    var body: some View {
        HStack(spacing: ReadingLogsLayout.summaryMetricSpacing) {
            MetricValue(
                value: readingDays,
                label: "阅读天数",
                valueSize: ReadingLogsLayout.summaryValueFontSize,
                labelSize: ReadingLogsLayout.summaryLabelFontSize,
                spacing: ReadingLogsLayout.summaryContentSpacing
            )
            MetricValue(
                value: finishedBooksCount,
                label: "读完书籍",
                valueSize: ReadingLogsLayout.summaryValueFontSize,
                labelSize: ReadingLogsLayout.summaryLabelFontSize,
                spacing: ReadingLogsLayout.summaryContentSpacing
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ReadingLogsLayout.summaryVerticalPadding)
    }
}

private struct ReadingLogDaySection: View {
    let group: LogDayGroup
    @Binding var expandedLogIDs: Set<UUID>
    let onEdit: (ReadingLog) -> Void
    let onDelete: (ReadingLog) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ReadingLogsLayout.dayHeaderToRecordsSpacing) {
            VStack(alignment: .leading, spacing: ReadingLogsLayout.dayDurationDividerTopSpacing) {
                HStack(alignment: .center) {
                    Text(group.title)
                        .font(.system(size: ReadingLogsLayout.dayTitleFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()

                    Spacer()

                    HStack(alignment: .center, spacing: ReadingLogsLayout.dayTotalUnitSpacing) {
                        Text("\(group.minutes)")
                            .font(.system(size: ReadingLogsLayout.dayTotalMinutesFontSize, weight: .semibold, design: .rounded))
                        Text("分钟")
                            .font(.system(size: ReadingLogsLayout.dayTotalUnitFontSize, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.accent)
                    .monospacedDigit()
                }

                ReadingLogDurationDivider(progress: group.durationProgress)
            }
            .padding(.bottom, ReadingLogsLayout.dayDurationDividerBottomSpacing)

            LazyVStack(spacing: ReadingLogsLayout.recordRowSpacing) {
                ForEach(group.items) { item in
                    ReadingLogPlainRow(
                        item: item,
                        isExpanded: expandedLogIDs.contains(item.id),
                        onToggle: {
                            toggleExpansion(for: item.id)
                        }
                    )
                    .contextMenu {
                        Button {
                            onEdit(item.log)
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            onDelete(item.log)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func toggleExpansion(for id: UUID) {
        withAnimation(ReadingLogsLayout.recordExpansionAnimation) {
            if expandedLogIDs.contains(id) {
                expandedLogIDs.remove(id)
            } else {
                expandedLogIDs.insert(id)
            }
        }
    }
}

private struct ReadingLogMonthHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: ReadingLogsLayout.monthHeaderFontSize, weight: .semibold))
            .foregroundStyle(AppTheme.accent.opacity(0.72))
            .textCase(.uppercase)
            .padding(.top, ReadingLogsLayout.monthHeaderTopPadding)
    }
}

private struct ReadingLogDurationDivider: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: ReadingLogsLayout.dayDurationDividerRadius, style: .continuous)
                    .fill(.primary.opacity(0.86))
                    .frame(height: ReadingLogsLayout.dayDurationDividerTrackHeight)

                RoundedRectangle(cornerRadius: ReadingLogsLayout.dayDurationDividerRadius, style: .continuous)
                    .fill(AppTheme.accent.opacity(0.72))
                    .frame(
                        width: progress > 0
                            ? max(proxy.size.width * min(max(progress, 0), 1), ReadingLogsLayout.dayDurationDividerMinimumFillWidth)
                            : 0,
                        height: ReadingLogsLayout.dayDurationDividerFillHeight
                    )
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: ReadingLogsLayout.dayDurationDividerFillHeight)
    }
}

private struct ReadingLogPlainRow: View {
    let item: ReadingLogDisplayItem
    let isExpanded: Bool
    let onToggle: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? ReadingLogsLayout.recordSummaryToDetailSpacing : 0) {
            summaryRow
            detailContainer
        }
        .padding(.top, ReadingLogsLayout.recordCollapsedVerticalPadding)
        .padding(.bottom, isExpanded ? ReadingLogsLayout.recordExpandedVerticalPadding : ReadingLogsLayout.recordCollapsedVerticalPadding)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var summaryRow: some View {
        HStack(alignment: .center, spacing: ReadingLogsLayout.recordHorizontalSpacing) {
            Text(item.log.book?.title ?? "未知书籍")
                .font(.system(size: ReadingLogsLayout.recordTitleFontSize, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .lastTextBaseline, spacing: ReadingLogsLayout.recordDurationUnitSpacing) {
                Text("\(item.log.minutes)")
                    .font(.system(size: ReadingLogsLayout.recordDurationFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText(colorScheme))
                    .monospacedDigit()

                Text("分钟")
                    .font(.system(size: ReadingLogsLayout.recordDurationUnitFontSize, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText(colorScheme))
            }
            .frame(minWidth: ReadingLogsLayout.recordDurationMinWidth, alignment: .trailing)
        }
    }

    private var detailRow: some View {
        HStack(spacing: ReadingLogsLayout.recordDetailSpacing) {
            Text(item.detailPagesCaption)
                .lineLimit(1)

            Spacer(minLength: ReadingLogsLayout.recordDetailSpacing)

            Text(item.timeRangeCaption)
                .lineLimit(1)
        }
        .font(.system(size: ReadingLogsLayout.recordDetailFontSize, weight: .medium))
        .foregroundStyle(AppTheme.tertiaryText(colorScheme))
        .monospacedDigit()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var detailContainer: some View {
        HStack(alignment: .center, spacing: ReadingLogsLayout.recordFocusLineSpacing) {
            RoundedRectangle(cornerRadius: ReadingLogsLayout.recordFocusLineWidth / 2, style: .continuous)
                .fill(AppTheme.accent.opacity(0.55))
                .frame(width: ReadingLogsLayout.recordFocusLineWidth, height: ReadingLogsLayout.recordFocusLineHeight)

            detailRow
        }
            .frame(height: isExpanded ? ReadingLogsLayout.recordDetailHeight : 0, alignment: .top)
            .clipped()
            .opacity(isExpanded ? 1 : 0)
            .allowsHitTesting(false)
    }
}

private struct ReadingLogDisplayItem: Identifiable {
    let log: ReadingLog
    let pagesRead: Int?

    var id: UUID { log.id }

    var detailPagesCaption: String {
        if let pagesRead, log.pageAfterReading > 0 {
            return "读了 \(pagesRead) 页，至第 \(log.pageAfterReading) 页"
        }
        if let pagesRead {
            return "读了 \(pagesRead) 页"
        }
        if log.pageAfterReading > 0 {
            return "读到第 \(log.pageAfterReading) 页"
        }
        return "未记录页码"
    }

    var timeRangeCaption: String {
        let end = log.date
        let start = end.addingTimeInterval(TimeInterval(-log.minutes * 60))
        return "\(AppDateText.time(start))-\(AppDateText.time(end))"
    }
}

private struct LogTimelineSection: Identifiable {
    let group: LogDayGroup
    let monthTitle: String?

    var id: Date { group.id }
}

struct ReadingLogRow: View {
    let log: ReadingLog

    var body: some View {
        HStack(alignment: .center, spacing: ReadingLogsLayout.detailRowHorizontalSpacing) {
            VStack(spacing: ReadingLogsLayout.detailRowDateSpacing) {
                Text("\(Calendar.current.component(.day, from: log.date))")
                    .font(.system(size: ReadingLogsLayout.detailRowDateDayFontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(AppDateText.month(log.date))
                    .font(.system(size: ReadingLogsLayout.detailRowDateMonthFontSize, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: ReadingLogsLayout.detailRowDateColumnWidth)

            VStack(alignment: .leading, spacing: ReadingLogsLayout.detailRowContentSpacing) {
                Text(log.book?.title ?? "未知书籍")
                    .font(.system(size: ReadingLogsLayout.detailRowTitleFontSize, weight: .regular))
                    .lineLimit(1)
                HStack(spacing: ReadingLogsLayout.detailRowMetaSpacing) {
                    Text("\(log.minutes) 分钟")
                    if log.pageAfterReading > 0 {
                        Text("读到第 \(log.pageAfterReading) 页")
                    }
                }
                .font(.system(size: ReadingLogsLayout.detailRowMetaFontSize, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            if log.book != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: ReadingLogsLayout.detailRowChevronFontSize, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, ReadingLogsLayout.detailRowHorizontalPadding)
        .padding(.vertical, ReadingLogsLayout.detailRowVerticalPadding)
        .contentShape(Rectangle())
    }
}

private struct LogDayGroup: Identifiable {
    let day: Date
    let items: [ReadingLogDisplayItem]

    var id: Date { day }

    var title: String {
        if Calendar.current.isDateInToday(day) {
            return "今天"
        }
        if Calendar.current.isDateInYesterday(day) {
            return "昨天"
        }
        return AppDateText.monthDay(day)
    }

    var minutes: Int {
        items.reduce(0) { $0 + $1.log.minutes }
    }

    var durationProgress: CGFloat {
        CGFloat(minutes) / ReadingLogsLayout.dayDurationReferenceMinutes
    }
}

#if DEBUG
#Preview("Reading Logs") {
    PreviewHost { data in
        NavigationStack {
            ReadingLogsView(books: data.books, logs: data.logs)
        }
    }
}

#Preview("Reading Logs Empty") {
    NavigationStack {
        ReadingLogsView(books: [], logs: [])
    }
    .modelContainer(PreviewData.emptyContainer())
}
#endif
