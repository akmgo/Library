#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

// MARK: - 🗓️ 核心月度记录视图

struct MonthlyRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReadingSession.date, order: .reverse) private var sessions: [ReadingSession]
    @Query(sort: \Book.title) private var books: [Book]

    @Binding var isBatchDeletePresented: Bool
    @Binding var selectedDates: Set<Date>

    @State private var visibleYear: Int = Calendar.current.component(.year, from: Date())
    @State private var visibleMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var monthlySnapshot: ReadingStatsCalculator.MonthlyArchiveSnapshot = .empty
    @State private var sessionsByDay: [Date: [ReadingSession]] = [:]

    private var sessionsFingerprint: String {
        "\(sessions.count)-\(sessions.first?.startedAt.timeIntervalSince1970 ?? 0)"
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack {
                    LazyVStack(spacing: 30) {
                        if monthlySnapshot.sections.isEmpty {
                            Text("暂无阅读记录")
                                .font(AppTypography.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 160)
                        } else {
                            ForEach(monthlySnapshot.sections) { section in
                                MonthGridSection(
                                    section: section,
                                    recordsDict: monthlySnapshot.durationByDay,
                                    isBatchMode: isBatchDeletePresented,
                                    selectedDates: $selectedDates,
                                    sessionsByDay: sessionsByDay,
                                    books: books
                                )
                                .id(section.id)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 160)
                    .padding(.bottom, 160)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .onReceive(NotificationCenter.default.publisher(for: .scrollToToday)) { _ in
                let calendar = Calendar.current
                let targetID = String(format: "%d-%02d", calendar.component(.year, from: Date()), calendar.component(.month, from: Date()))
                withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(targetID, anchor: .center) }
            }
        }
        // ================= 2. 顶层悬浮玻璃 Header =================
        .overlay(alignment: .top) {
            AppPageHeader(
                contentID: "\(visibleYear)-\(visibleMonth)",
                titleContent: {
                    AppHeaderTitle("\(visibleYear)年 \(visibleMonth)月", subtitle: "按月份查看每天的阅读痕迹。")
                },
                trailingContent: { PageStatsCompact(items: monthlyHeaderStats) }
            )
        }
        .overlay(alignment: .bottom) {
            if isBatchDeletePresented {
                monthlyBatchDeleteCapsule
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .ignoresSafeArea(edges: .top)
        .onAppear {
            refreshMonthlySnapshot()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                NotificationCenter.default.post(name: .scrollToToday, object: nil)
            }
        }
        .onChange(of: sessionsFingerprint) { _, _ in
            refreshMonthlySnapshot()
        }
    }

    private var monthlyHeaderStats: [PageStatItemData] {
        let calendar = Calendar.current
        let entries = monthlySnapshot.durationByDay.filter { date, _ in
            calendar.component(.year, from: date) == visibleYear
                && calendar.component(.month, from: date) == visibleMonth
        }
        let days = entries.filter { $0.1 > 0 }.count
        let minutes = Int(entries.reduce(0) { $0 + max($1.1, 0) } / 60)
        let avg = days > 0 ? minutes / days : 0
        let sortedDays = entries.filter { $0.1 > 0 }.map { $0.0 }.sorted()
        var longest = 0, current = 0
        for (i, day) in sortedDays.enumerated() {
            if i == 0 || calendar.date(byAdding: .day, value: 1, to: sortedDays[i - 1]) == day {
                current += 1
            } else { current = 1 }
            longest = max(longest, current)
        }
        return [
            PageStatItemData(title: "本月阅读", value: "\(minutes)", color: .indigo),
            PageStatItemData(title: "阅读天数", value: "\(days)", color: AppColors.readingAmber),
            PageStatItemData(title: "最高连续", value: "\(longest)", color: .teal),
            PageStatItemData(title: "日均阅读", value: "\(avg)", color: .pink),
        ]
    }


    private var monthlyBatchDeleteCapsule: some View {
        HStack(spacing: 14) {
            Button {
                withAnimation { selectedDates.removeAll(); isBatchDeletePresented = false }
            } label: {
                Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).frame(width: 28, height: 28)
            }
            .buttonStyle(.plain).help("取消")

            Text("已选择 \(selectedDates.count) 天")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                let calendar = Calendar.current
                let targets = selectedDates.flatMap { day in
                    sessionsByDay[calendar.startOfDay(for: day)] ?? []
                }
                for s in targets { modelContext.delete(s) }
                try? modelContext.save()
                withAnimation { selectedDates.removeAll(); isBatchDeletePresented = false }
            } label: {
                Image(systemName: "trash").font(.system(size: 16, weight: .semibold)).frame(width: 28, height: 28)
            }
            .buttonStyle(.plain).disabled(selectedDates.isEmpty).help("删除")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .appCapsuleStyle(tint: AppColors.readingAmber, fillOpacity: 0.12, strokeOpacity: 0.10)
    }

    private func refreshMonthlySnapshot() {
        let calendar = Calendar.current
        monthlySnapshot = ReadingStatsCalculator.monthlyArchiveSnapshot(sessions: sessions, calendar: calendar)
        sessionsByDay = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.startedAt) }
    }

}

// MARK: - 无缝网格分段

private struct MonthGridSection: View {
    let section: ReadingStatsCalculator.ReadingMonthSection
    let recordsDict: [Date: TimeInterval]
    let isBatchMode: Bool
    @Binding var selectedDates: Set<Date>
    let sessionsByDay: [Date: [ReadingSession]]
    let books: [Book]
    let booksByID: [String: Book]
    let monthTotalMinutes: Int

    init(
        section: ReadingStatsCalculator.ReadingMonthSection,
        recordsDict: [Date: TimeInterval],
        isBatchMode: Bool,
        selectedDates: Binding<Set<Date>>,
        sessionsByDay: [Date: [ReadingSession]],
        books: [Book]
    ) {
        self.section = section
        self.recordsDict = recordsDict
        self.isBatchMode = isBatchMode
        self._selectedDates = selectedDates
        self.sessionsByDay = sessionsByDay
        self.books = books
        self.booksByID = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })
        self.monthTotalMinutes = section.days.compactMap { d -> Int? in
            guard let date = d, let duration = recordsDict[Calendar.current.startOfDay(for: date)] else { return nil }
            return Int(duration / 60)
        }.reduce(0, +)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .lastTextBaseline) {
                Text(String(format: "%d月", section.month))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                
                if monthTotalMinutes > 0 {
                    Text("\(monthTotalMinutes / 60)h \(monthTotalMinutes % 60)m")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                }
                
                Rectangle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 2)
                    .padding(.leading, 8)
            }
            .padding(.bottom, 8)
            
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<section.days.count, id: \.self) { index in
                    if let date = section.days[index] {
                        let startOfDay = Calendar.current.startOfDay(for: date)
                        let daySessions = sessionsByDay[startOfDay] ?? []
                        let snapshot = ReadingStatsCalculator.ReadingDaySnapshot(
                            date: date,
                            duration: recordsDict[startOfDay],
                            sessions: daySessions,
                            booksByID: booksByID
                        )
                        DayCardView(
                            snapshot: snapshot,
                            isBatchMode: isBatchMode,
                            isSelected: selectedDates.contains(startOfDay),
                            onToggle: {
                                if selectedDates.contains(startOfDay) { selectedDates.remove(startOfDay) }
                                else { selectedDates.insert(startOfDay) }
                            }
                        )
                        .equatable()
                    } else {
                        Color.clear.frame(height: 110)
                    }
                }
            }
        }
    }
}

// MARK: - ✨ 高定方形数据卡片 (每日网格)

private struct DayCardView: View, Equatable {
    let snapshot: ReadingStatsCalculator.ReadingDaySnapshot
    let isBatchMode: Bool
    let isSelected: Bool
    let onToggle: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showPopover = false

    static func == (lhs: DayCardView, rhs: DayCardView) -> Bool {
        lhs.snapshot == rhs.snapshot
            && lhs.isBatchMode == rhs.isBatchMode
            && lhs.isSelected == rhs.isSelected
    }

    var body: some View {
        let isCelebration = snapshot.dailyMinutes > 50

        ZStack {
            Rectangle()
                .fill(snapshot.hasRead ? Color.primary.opacity(0.06) : Color.secondary.opacity(0.03))

            if snapshot.hasRead {
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(VisualEngines.ReadingHeatmap.gradient(for: snapshot.dailyMinutes))
                        .frame(height: VisualEngines.ReadingHeatmap.height(for: snapshot.dailyMinutes))
                }
            }

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    if isBatchMode {
                        ZStack {
                            if snapshot.isToday { Circle().fill(Color.primary).frame(width: 24, height: 24) }
                            Text(snapshot.dayNumberText)
                                .font(.system(size: 16, weight: snapshot.isToday ? .bold : .semibold, design: .rounded))
                                .foregroundColor(snapshot.isToday ? AppColors.primaryBackground(for: colorScheme) : (snapshot.hasRead ? .primary : .secondary.opacity(0.4)))
                        }
                    } else {
                        ZStack {
                            if snapshot.isToday { Circle().fill(Color.primary).frame(width: 24, height: 24) }
                            Text(snapshot.dayNumberText)
                                .font(.system(size: 16, weight: snapshot.isToday ? .bold : .semibold, design: .rounded))
                                .foregroundColor(snapshot.isToday ? AppColors.primaryBackground(for: colorScheme) : (snapshot.hasRead ? .primary : .secondary.opacity(0.4)))
                        }
                    }
                    Spacer()
                    if snapshot.hasRead && !isBatchMode {
                        HStack(spacing: 2) {
                            if isCelebration { Image(systemName: "flame.fill").font(.system(size: 9)) }
                            Text("\(snapshot.dailyMinutes)m")
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(VisualEngines.ReadingHeatmap.shadowColor(for: snapshot.dailyMinutes))
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .appCapsuleStyle(tint: VisualEngines.ReadingHeatmap.shadowColor(for: snapshot.dailyMinutes), fillOpacity: 0.12)
                    }
                }
                .padding(10)
                Spacer()
            }
        }
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isBatchMode && isSelected ? Color.blue : Color.primary.opacity(0.05), lineWidth: isBatchMode && isSelected ? 3 : 1))
        .onTapGesture {
            if isBatchMode { onToggle() }
            else if snapshot.hasRead { showPopover = true }
        }
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(snapshot.dayLabel)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Spacer()
                    Text("\(snapshot.totalMinutes) 分钟")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.readingAmber)
                }

                if !snapshot.bookSummaries.isEmpty {
                    Divider()
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
            .frame(width: 280)
            .padding(20)
        }
    }
}

private struct GlassControlButton: View {
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundColor(.primary)
                .frame(width: 36, height: 36)
                .background(Color.secondary.opacity(0.1)).clipShape(Circle())
        }.buttonStyle(.plain)
    }
}

extension Notification.Name {
    static let scrollToMonth = Notification.Name("scrollToMonth")
    static let scrollToToday = Notification.Name("scrollToToday")
}

#endif
