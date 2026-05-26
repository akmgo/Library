#if os(iOS)
import SwiftUI
import SwiftData

// MARK: - 月度记录 (iOS 原生版)

struct MobileMonthlyRecordView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReadingSession.date, order: .reverse) private var sessions: [ReadingSession]
    @Query(sort: \Book.title) private var books: [Book]

    @State private var displayYear: Int = Calendar.current.component(.year, from: Date())
    @State private var displayMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var isEditing = false
    @State private var selectedDates: Set<Date> = []
    @State private var showBatchDeleteAlert = false

    private let calendar = Calendar.current

    // MARK: - 当月数据

    private var monthSessions: [ReadingSession] {
        sessions.filter {
            calendar.component(.year, from: $0.startedAt) == displayYear &&
            calendar.component(.month, from: $0.startedAt) == displayMonth
        }
    }

    private var sessionsByDay: [(date: Date, sessions: [ReadingSession])] {
        let grouped = Dictionary(grouping: monthSessions) { calendar.startOfDay(for: $0.startedAt) }
        return grouped.map { ($0.key, $0.value) }.sorted { $0.date > $1.date }
    }

    private var booksByID: [String: Book] {
        Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })
    }

    private var totalMinutes: Int {
        Int(monthSessions.reduce(0) { $0 + $1.duration } / 60)
    }

    private var activeDays: Int {
        Set(monthSessions.map { calendar.startOfDay(for: $0.startedAt) }).count
    }

    private var longestStreak: Int {
        let sortedDays = Set(monthSessions.map { calendar.startOfDay(for: $0.startedAt) }).sorted()
        var longest = 0, current = 0
        for (i, day) in sortedDays.enumerated() {
            if i == 0 || calendar.date(byAdding: .day, value: 1, to: sortedDays[i - 1]) == day {
                current += 1
            } else { current = 1 }
            longest = max(longest, current)
        }
        return longest
    }

    private var dailyAverage: Int {
        activeDays > 0 ? totalMinutes / activeDays : 0
    }

    private var monthStats: [PageStatItemData] {
        [
            PageStatItemData(title: "本月阅读", value: "\(totalMinutes)", color: .indigo),
            PageStatItemData(title: "阅读天数", value: "\(activeDays)", color: AppColors.readingAmber),
            PageStatItemData(title: "最高连续", value: "\(longestStreak)", color: .teal),
            PageStatItemData(title: "日均阅读", value: "\(dailyAverage)", color: .pink),
        ]
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: AppSpacing.l) {
                    MobilePageStatsHeader(items: monthStats)

                    monthNavigator

                    if sessionsByDay.isEmpty {
                        emptyMonthView
                            .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: AppSpacing.s) {
                            ForEach(sessionsByDay, id: \.date) { item in
                                let snapshot = ReadingStatsCalculator.ReadingDaySnapshot(
                                    date: item.date,
                                    duration: nil,
                                    sessions: item.sessions,
                                    booksByID: booksByID,
                                    calendar: calendar
                                )
                                Button(action: {
                                    if isEditing {
                                        toggleDate(item.date)
                                    }
                                }) {
                                    DayReadingCard(snapshot: snapshot)
                                        .equatable()
                                        .overlay(
                                            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                                                .stroke(isEditing && selectedDates.contains(item.date) ? Color.blue : Color.clear, lineWidth: 3)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, AppSpacing.l)
                    }
                }
                .padding(.bottom, AppSpacing.emptyState)
            }
            .background(AppColors.primaryBackground(for: colorScheme).ignoresSafeArea())
            .toolbar { monthlyToolbar }
            .alert("批量删除", isPresented: $showBatchDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive, action: batchDelete)
            } message: {
                Text("确定删除选中 \(selectedDates.count) 天的阅读记录吗？此操作不可撤销。")
            }
        }
    }

    @ToolbarContentBuilder
    private var monthlyToolbar: some ToolbarContent {
        if isEditing {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 16) {
                    Button("取消") { withAnimation { exitEditMode() } }
                    if !selectedDates.isEmpty {
                        Text("\(selectedDates.count)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            if !selectedDates.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showBatchDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(AppColors.danger)
                    }
                }
            }
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { withAnimation { isEditing = true } }) {
                    Image(systemName: "checklist")
                }
            }
        }
    }

    // MARK: - 月份导航

    @ViewBuilder
    private var monthNavigator: some View {
        HStack(spacing: 0) {
            Button(action: { goToPreviousMonth() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("\(String(displayYear))年 \(displayMonth)月")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            Button(action: { goToNextMonth() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.l)
    }

    private var emptyMonthView: some View {
        VStack(spacing: AppSpacing.m) {
            Image(systemName: "book.pages")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.25))
            Text("本月暂无阅读记录")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 月份切换

    private func goToPreviousMonth() {
        if displayMonth == 1 { displayMonth = 12; displayYear -= 1 }
        else { displayMonth -= 1 }
    }

    private func goToNextMonth() {
        if displayMonth == 12 { displayMonth = 1; displayYear += 1 }
        else { displayMonth += 1 }
    }

    // MARK: - 批量操作

    private func toggleDate(_ date: Date) {
        if selectedDates.contains(date) { selectedDates.remove(date) }
        else { selectedDates.insert(date) }
    }

    private func exitEditMode() {
        isEditing = false
        selectedDates = []
    }

    private func batchDelete() {
        let targets = monthSessions.filter { selectedDates.contains(calendar.startOfDay(for: $0.startedAt)) }
        for session in targets { modelContext.delete(session) }
        try? modelContext.save()
        exitEditMode()
    }
}

// MARK: - 每日阅读卡片

private struct DayReadingCard: View, Equatable {
    let snapshot: ReadingStatsCalculator.ReadingDaySnapshot

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(snapshot.dayLabel)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(snapshot.totalMinutes) 分钟")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.readingAmber)
                }

                if !snapshot.bookSummaries.isEmpty {
                    ForEach(snapshot.bookSummaries) { summary in
                        HStack {
                            Text("《\(summary.title)》")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary.opacity(0.8))
                                .lineLimit(1)
                            Spacer()
                            if !summary.detail.isEmpty {
                                Text(summary.detail)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.teal)
                            }
                        }
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("月度记录") {
    PreviewWithData {
        MobileMonthlyRecordView()
    }
}
#endif

#endif
