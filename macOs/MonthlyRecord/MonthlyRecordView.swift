#if os(macOS)
import AppKit
import Charts
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
    @Query(sort: \ReadingSession.date, order: .reverse) private var sessions: [ReadingSession]
    
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
                                MonthGridSection(section: section, recordsDict: monthlySnapshot.durationByDay)
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
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Text(String(format: "%d年", visibleYear))
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)
                            Text("\(visibleMonth)月")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 170, alignment: .leading)
                    },
                    trailingContent: {
                        MonthlySparklineView(year: visibleYear, month: visibleMonth, recordsDict: monthlySnapshot.durationByDay)
                            .frame(height: 36)
                            .padding(.horizontal, 20)
                    }
                )
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
    
}

// MARK: - 无缝网格分段

private struct MonthGridSection: View {
    let section: ReadingStatsCalculator.ReadingMonthSection
    let recordsDict: [Date: TimeInterval]
    
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
                        DayCardView(date: date, duration: recordsDict[Calendar.current.startOfDay(for: date)])
                    } else {
                        Color.clear.frame(height: 110)
                    }
                }
            }
        }
    }
}

// MARK: - 顶部玻璃区专属：月度动态微缩曲线图

private struct MonthlySparklineView: View {
    let year: Int
    let month: Int
    let recordsDict: [Date: TimeInterval]
    
    @State private var chartData: [(day: Int, minutes: Double)] = []
    
    var body: some View {
        Chart(chartData, id: \.day) { item in
            LineMark(
                x: .value("Day", item.day),
                y: .value("Minutes", item.minutes)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.indigo.gradient)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            
            AreaMark(
                x: .value("Day", item.day),
                y: .value("Minutes", item.minutes)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(colors: [Color.indigo.opacity(0.3), Color.clear], startPoint: .top, endPoint: .bottom)
            )
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .animation(.appFluidSpring, value: chartData.map { $0.minutes })
        .onAppear { updateData() }
        .onChange(of: year) { _, _ in updateData() }
        .onChange(of: month) { _, _ in updateData() }
        .onChange(of: recordsDict) { _, _ in updateData() }
    }
    
    private func updateData() {
        let cal = Calendar.current
        var comps = DateComponents(year: year, month: month)
        guard let startOfMonth = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: startOfMonth) else { return }
        
        var data: [(Int, Double)] = []
        for day in range {
            comps.day = day
            if let date = cal.date(from: comps),
               let duration = recordsDict[cal.startOfDay(for: date)]
            {
                data.append((day, duration / 60.0))
            } else {
                data.append((day, 0))
            }
        }
        chartData = data
    }
}

// MARK: - ✨ 高定方形数据卡片 (每日网格)

private struct DayCardView: View {
    let date: Date
    let duration: TimeInterval?
    
    @State private var isHovered = false
    
    var body: some View {
        let calendar = Calendar.current
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
                    ZStack {
                        if isToday { Circle().fill(Color.primary).frame(width: 24, height: 24) }
                        Text(dateString)
                            .font(.system(size: 16, weight: isToday ? .bold : .semibold, design: .rounded))
                            .foregroundColor(isToday ? Color(nsColor: .windowBackgroundColor) : (hasRead ? .primary : .secondary.opacity(0.4)))
                    }
                    Spacer()
                    if hasRead {
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
            
            // ✨ 删除了展示书名的部分，让界面保持极简的热力图效果
        }
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(isHovered ? 0.2 : 0.05), lineWidth: isHovered ? 2 : 1))
        .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.0), radius: isHovered ? 8 : 0, y: isHovered ? 3 : 0)
        .scaleEffect(isHovered ? 1.012 : 1.0)
        .zIndex(isHovered ? 1 : 0)
        .animation(.appSnappy, value: isHovered)
        .onHover { h in
            withAnimation(.appSnappy) { isHovered = h }
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
