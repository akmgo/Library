#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

// MARK: - 滚动监听器

private struct ScrollBoundsKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - 🗓️ 核心月度记录视图

struct MonthlyRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReadingSession.date, order: .reverse) private var sessions: [ReadingSession]
    @Query(sort: \Book.title) private var books: [Book]

    @Binding var isBatchDeletePresented: Bool
    @Binding var selectedDates: Set<Date>

    @State private var visibleYear: Int = Calendar.current.component(.year, from: Date())
    @State private var visibleMonth: Int = Calendar.current.component(.month, from: Date())
    
    private var monthlySnapshot: ReadingStatsCalculator.MonthlyArchiveSnapshot {
        ReadingStatsCalculator.monthlyArchiveSnapshot(sessions: sessions)
    }
    
    var body: some View {
        GeometryReader { mainGeo in
            // ================= 1. 底层无缝连续滚动区 =================
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack {
                        VStack(spacing: 30) {
                            ForEach(monthlySnapshot.sections) { section in
                                MonthGridSection(
                                    section: section,
                                    recordsDict: monthlySnapshot.durationByDay,
                                    isBatchMode: isBatchDeletePresented,
                                    selectedDates: $selectedDates,
                                    sessions: sessions,
                                    books: books
                                )
                                .id(section.id)
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(key: ScrollBoundsKey.self, value: [section.id: geo.frame(in: .global)])
                                        }
                                    )
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 160)
                        .padding(.bottom, mainGeo.size.height / 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                
                // 滚动监听事件群
                .onPreferenceChange(ScrollBoundsKey.self) { bounds in
                    let screenCenter = mainGeo.frame(in: .global).midY
                    if let best = bounds.min(by: { abs($0.value.midY - screenCenter) < abs($1.value.midY - screenCenter) }) {
                        let parts = best.key.split(separator: "-")
                        if parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]) {
                            if self.visibleYear != y || self.visibleMonth != m {
                                self.visibleYear = y; self.visibleMonth = m
                            }
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .scrollToToday)) { _ in
                    let calendar = Calendar.current
                    let targetID = String(format: "%d-%02d", calendar.component(.year, from: Date()), calendar.component(.month, from: Date()))
                    
                    withAnimation(.appDataChange) { proxy.scrollTo(targetID, anchor: .center) }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                NotificationCenter.default.post(name: .scrollToToday, object: nil)
            }
        }
    }

    private var monthlyHeaderStats: [PageStatItemData] {
        let avgMinutes = visibleMonthReadingDays > 0 ? visibleMonthReadingMinutes / visibleMonthReadingDays : 0
        return [
            PageStatItemData(title: "本月阅读", value: "\(visibleMonthReadingMinutes)", color: .indigo),
            PageStatItemData(title: "阅读天数", value: "\(visibleMonthReadingDays)", color: AppColors.readingAmber),
            PageStatItemData(title: "最高连续", value: "\(visibleMonthLongestStreak)", color: .teal),
            PageStatItemData(title: "日均阅读", value: "\(avgMinutes)", color: .pink),
        ]
    }

    private var visibleMonthLongestStreak: Int {
        let calendar = Calendar.current
        let daysWithReading = visibleMonthEntries
            .filter { $0.1 > 0 }
            .map { calendar.startOfDay(for: $0.0) }
            .sorted()
        return ReadingStatsCalculator.longestStreak(in: daysWithReading, calendar: calendar)
    }

    private var visibleMonthEntries: [(Date, TimeInterval)] {
        let calendar = Calendar.current
        return monthlySnapshot.durationByDay.filter { date, _ in
            calendar.component(.year, from: date) == visibleYear
                && calendar.component(.month, from: date) == visibleMonth
        }
    }

    private var visibleMonthReadingDays: Int {
        visibleMonthEntries.filter { $0.1 > 0 }.count
    }

    private var visibleMonthDuration: TimeInterval {
        visibleMonthEntries.reduce(0) { $0 + max($1.1, 0) }
    }

    private var visibleMonthReadingMinutes: Int {
        Int(visibleMonthDuration / 60)
    }

    private var visibleMonthSessions: [ReadingSession] {
        let calendar = Calendar.current
        return sessions.filter {
            calendar.component(.year, from: $0.startedAt) == visibleYear &&
            calendar.component(.month, from: $0.startedAt) == visibleMonth
        }
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
                let targets = visibleMonthSessions.filter { selectedDates.contains(calendar.startOfDay(for: $0.startedAt)) }
                for s in targets { modelContext.delete(s) }
                try? modelContext.save()
                withAnimation { selectedDates.removeAll(); isBatchDeletePresented = false }
            } label: {
                Image(systemName: "trash").font(.system(size: 16, weight: .semibold)).frame(width: 28, height: 28)
            }
            .buttonStyle(.plain).disabled(selectedDates.isEmpty).help("删除")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }

}

// MARK: - 无缝网格分段

private struct MonthGridSection: View {
    let section: ReadingStatsCalculator.ReadingMonthSection
    let recordsDict: [Date: TimeInterval]
    let isBatchMode: Bool
    @Binding var selectedDates: Set<Date>
    let sessions: [ReadingSession]
    let books: [Book]
    
    private var monthTotalMinutes: Int {
        section.days.compactMap { d -> Int? in
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
                        let daySessions = sessions.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: date) }
                        DayCardView(
                            date: date,
                            duration: recordsDict[Calendar.current.startOfDay(for: date)],
                            isBatchMode: isBatchMode,
                            isSelected: selectedDates.contains(Calendar.current.startOfDay(for: date)),
                            onToggle: {
                                let startOfDay = Calendar.current.startOfDay(for: date)
                                if selectedDates.contains(startOfDay) { selectedDates.remove(startOfDay) }
                                else { selectedDates.insert(startOfDay) }
                            },
                            daySessions: daySessions,
                            books: books
                        )
                    } else {
                        Color.clear.frame(height: 110)
                    }
                }
            }
        }
    }
}

// MARK: - ✨ 高定方形数据卡片 (每日网格)

private struct DayCardView: View {
    let date: Date
    let duration: TimeInterval?
    let isBatchMode: Bool
    let isSelected: Bool
    let onToggle: () -> Void
    let daySessions: [ReadingSession]
    let books: [Book]

    @State private var isHovered = false
    @State private var showPopover = false

    private let calendar = Calendar.current

    private var totalMinutes: Int {
        Int(daySessions.reduce(0) { $0 + $1.duration } / 60)
    }

    private var bookSummaries: [(title: String, detail: String)] {
        var merged: [String: (totalDelta: Double, unit: ProgressUnit, totalDuration: TimeInterval)] = [:]
        for session in daySessions {
            guard let bookID = session.book?.id, books.contains(where: { $0.id == bookID }) else { continue }
            var entry = merged[bookID] ?? (0, session.progressUnit, 0)
            entry.totalDelta += session.deltaAmount
            entry.totalDuration += session.duration
            merged[bookID] = entry
        }
        return merged.compactMap { bookID, data in
            guard let book = books.first(where: { $0.id == bookID }) else { return nil }
            let mins = Int(data.totalDuration / 60)
            var parts: [String] = []
            if mins > 0 { parts.append("\(mins)分钟") }
            if data.totalDelta > 0 {
                switch data.unit {
                case .page: parts.append("+\(Int(data.totalDelta))页")
                case .percent: parts.append("+\(Int(data.totalDelta))%")
                case .chapter: parts.append("+\(Int(data.totalDelta))章")
                }
            }
            return (book.title, parts.joined(separator: " · "))
        }
    }

    var body: some View {
        let isToday = calendar.isDateInToday(date)
        let hasRead = duration != nil
        let dateString = "\(calendar.component(.day, from: date))"
        let totalSeconds = Int(duration ?? 0)
        let dailyMinutes = totalSeconds > 0 ? max(1, totalSeconds / 60) : 0
        let isCelebration = dailyMinutes > 50

        ZStack {
            Rectangle()
                .fill(hasRead ? Color(nsColor: .controlBackgroundColor) : Color.secondary.opacity(0.03))

            if hasRead {
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(VisualEngines.ReadingHeatmap.gradient(for: dailyMinutes))
                        .frame(height: VisualEngines.ReadingHeatmap.height(for: dailyMinutes))
                        .shadow(color: VisualEngines.ReadingHeatmap.shadowColor(for: dailyMinutes).opacity(0.5), radius: isHovered ? 8 : 4, y: -2)
                }
            }

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    if isBatchMode {
                        ZStack {
                            if isToday { Circle().fill(Color.primary).frame(width: 24, height: 24) }
                            Text(dateString)
                                .font(.system(size: 16, weight: isToday ? .bold : .semibold, design: .rounded))
                                .foregroundColor(isToday ? Color(nsColor: .windowBackgroundColor) : (hasRead ? .primary : .secondary.opacity(0.4)))
                        }
                    } else {
                        ZStack {
                            if isToday { Circle().fill(Color.primary).frame(width: 24, height: 24) }
                            Text(dateString)
                                .font(.system(size: 16, weight: isToday ? .bold : .semibold, design: .rounded))
                                .foregroundColor(isToday ? Color(nsColor: .windowBackgroundColor) : (hasRead ? .primary : .secondary.opacity(0.4)))
                        }
                    }
                    Spacer()
                    if hasRead && !isBatchMode {
                        HStack(spacing: 2) {
                            if isCelebration { Image(systemName: "flame.fill").font(.system(size: 9)) }
                            Text("\(dailyMinutes)m")
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(VisualEngines.ReadingHeatmap.shadowColor(for: dailyMinutes))
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                    }
                }
                .padding(10)
                Spacer()
            }
        }
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isBatchMode && isSelected ? Color.blue : Color.primary.opacity(isHovered ? 0.2 : 0.05), lineWidth: isBatchMode && isSelected ? 3 : (isHovered ? 2 : 1)))
        .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.0), radius: isHovered ? 8 : 0, y: isHovered ? 3 : 0)
        .scaleEffect(isHovered ? 1.012 : 1.0)
        .zIndex(isHovered ? 1 : 0)
        .animation(.appSnappy, value: isHovered)
        .onHover { h in
            withAnimation(.appSnappy) { isHovered = h }
        }
        .onTapGesture {
            if isBatchMode { onToggle() }
            else if hasRead { showPopover = true }
        }
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    let day = calendar.component(.day, from: date)
                    let weekday = calendar.component(.weekday, from: date)
                    let names = ["日", "一", "二", "三", "四", "五", "六"]
                    Text("\(day)日 周\(names[weekday - 1])")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Spacer()
                    Text("\(totalMinutes) 分钟")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.readingAmber)
                }

                if !bookSummaries.isEmpty {
                    Divider()
                    ForEach(Array(bookSummaries.enumerated()), id: \.offset) { _, summary in
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
            .padding(20)
            .frame(width: 320)
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
