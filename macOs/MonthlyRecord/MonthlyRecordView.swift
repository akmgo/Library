#if os(macOS)
import AppKit
import Charts
import SwiftData
import SwiftUI

// MARK: - 数据模型与滚动监听器

private struct MonthSection: Identifiable {
    let id: String
    let year: Int
    let month: Int
    let days: [Date?]
}

private struct ScrollBoundsKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - 🗓️ 核心月度记录视图

struct MonthlyRecordView: View {
    @Environment(\.modelContext) private var modelContext
    
    let daysOfWeek = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    
    @State private var cachedRecordsDict: [Date: ReadingRecord] = [:]
    @State private var cachedSections: [MonthSection] = []
    
    @State private var visibleYear: Int = Calendar.current.component(.year, from: Date())
    @State private var visibleMonth: Int = Calendar.current.component(.month, from: Date())
    
    // ✨ 核心机制：强制状态驱动首屏动画锁
    @State private var isEntranceAnimated: Bool = false
    
    var body: some View {
        GeometryReader { mainGeo in
            // ================= 1. 底层无缝连续滚动区 (彻底移除外层 ZStack 与底层背景) =================
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack {
                        VStack(spacing: 30) {
                            ForEach(cachedSections) { section in
                                MonthGridSection(section: section, recordsDict: cachedRecordsDict)
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
                // ✨ 核心修复：将动画修饰符挂载在 ScrollView 的最外层！
                // 保证 ScrollView 内部的坐标系绝对静止，让 scrollTo 能 100% 精准锁定屏幕中央！
                .opacity(isEntranceAnimated ? 1.0 : 0.0)
                .offset(y: isEntranceAnimated ? 0 : 200)
                .scaleEffect(isEntranceAnimated ? 1.0 : 0.98, anchor: .center)
                .animation(.appFluidSpring, value: isEntranceAnimated)
                
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
                .onReceive(NotificationCenter.default.publisher(for: .scrollToMonth)) { notification in
                    if let targetID = notification.object as? String {
                        withAnimation(.appFluidSpring) { proxy.scrollTo(targetID, anchor: .center) }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .scrollToToday)) { _ in
                    let calendar = Calendar.current
                    let targetID = String(format: "%d-%02d", calendar.component(.year, from: Date()), calendar.component(.month, from: Date()))
                    
                    if isEntranceAnimated {
                        withAnimation(.appFluidSpring) { proxy.scrollTo(targetID, anchor: .center) }
                    } else {
                        proxy.scrollTo(targetID, anchor: .center)
                    }
                }
            }
            // ================= 2. 顶层悬浮玻璃 Header (转化为 overlay) =================
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Text(String(format: "%d年", visibleYear))
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)
                            Text("\(visibleMonth)月")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 170, alignment: .leading)
                        .opacity(isEntranceAnimated ? 1.0 : 0.0)
                        .offset(x: isEntranceAnimated ? 0 : -200)
                                                                                                        
                        MonthlySparklineView(year: visibleYear, month: visibleMonth, recordsDict: cachedRecordsDict)
                            .frame(height: 36)
                            .padding(.horizontal, 20)
                            .opacity(isEntranceAnimated ? 1.0 : 0.0)
                            .offset(x: isEntranceAnimated ? 0 : -200)
                                                                                                        
                        HStack(spacing: 12) {
                            GlassControlButton(icon: "chevron.left") { jumpToMonth(offset: -1) }
                            Button(action: { NotificationCenter.default.post(name: .scrollToToday, object: nil) }) {
                                Text("今天").font(.system(size: 13, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .background(Color.secondary.opacity(0.1)).clipShape(Capsule())
                            GlassControlButton(icon: "chevron.right") { jumpToMonth(offset: 1) }
                        }
                        .frame(width: 160, alignment: .trailing)
                        .opacity(isEntranceAnimated ? 1.0 : 0.0)
                        .offset(x: isEntranceAnimated ? 0 : 200)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 40)
                    .padding(.bottom, 16)
                    .animation(.appFluidSpring, value: isEntranceAnimated)
                    
                    HStack(spacing: 20) {
                        ForEach(daysOfWeek, id: \.self) { day in
                            Text(day).font(.system(size: 13, weight: .bold)).foregroundColor(.secondary.opacity(0.6)).frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 40).padding(.bottom, 16)
                    .opacity(isEntranceAnimated ? 1.0 : 0.0)
                    .offset(y: isEntranceAnimated ? 0 : 20)
                    .animation(.appFluidSpring, value: isEntranceAnimated)
                    
                    Divider()
                        .opacity(isEntranceAnimated ? 1.0 : 0.0)
                        .animation(.appFluidSpring, value: isEntranceAnimated)
                }
                .background(
                    Color.clear
                        .background(.ultraThinMaterial)
                        .opacity(0.85)
                )
                .ignoresSafeArea(edges: .top)
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .ignoresSafeArea(edges: .top)
        .onAppear {
            isEntranceAnimated = false
            self.buildContinuousData(animate: false)
        }
        // ✨ 这里使用了全局强类型通知
        .onReceive(NotificationCenter.default.publisher(for: .libraryDidUpdate)) { _ in
            self.buildContinuousData(animate: true)
        }
    }
    
    // MARK: - ✨ 异步引擎逻辑
    
    private func buildContinuousData(animate: Bool) {
        Task { @MainActor in
            let calendar = Calendar.current
            let allRecords = (try? modelContext.fetch(FetchDescriptor<ReadingRecord>())) ?? []
            
            var dict = [Date: ReadingRecord]()
            for record in allRecords {
                dict[calendar.startOfDay(for: record.date)] = record
            }
            
            let today = Date()
            let earliestDate = allRecords.compactMap { $0.date }.min() ?? calendar.date(byAdding: .month, value: -6, to: today)!
            
            var currentMonthDate = calendar.date(from: calendar.dateComponents([.year, .month], from: earliestDate))!
            let endMonthDate = calendar.date(byAdding: .month, value: 1, to: calendar.date(from: calendar.dateComponents([.year, .month], from: today))!)!
            
            var sections = [MonthSection]()
            
            while currentMonthDate <= endMonthDate {
                let year = calendar.component(.year, from: currentMonthDate)
                let month = calendar.component(.month, from: currentMonthDate)
                let id = String(format: "%d-%02d", year, month)
                let days = extractDaysInMonth(for: currentMonthDate)
                sections.append(MonthSection(id: id, year: year, month: month, days: days))
                
                currentMonthDate = calendar.date(byAdding: .month, value: 1, to: currentMonthDate)!
            }
            
            if animate && self.isEntranceAnimated {
                withAnimation(.appFluidSpring) {
                    self.cachedRecordsDict = dict
                    self.cachedSections = sections
                }
            } else {
                self.cachedRecordsDict = dict
                self.cachedSections = sections
            }
            
            if !self.isEntranceAnimated {
                // 1. 等待排版框架初步建立
                try? await Task.sleep(nanoseconds: 30_000_000)
                
                // 2. 发送滚动指令（此刻内部坐标系统稳定且准确）
                NotificationCenter.default.post(name: .scrollToToday, object: nil)
                
                // 3. 确保定格在当月，彻底停稳
                try? await Task.sleep(nanoseconds: 80_000_000)
                
                // 4. 起飞！
                withAnimation(.appFluidSpring) {
                    self.isEntranceAnimated = true
                }
            }
        }
    }
    
    private func jumpToMonth(offset: Int) {
        var newMonth = visibleMonth + offset; var newYear = visibleYear
        if newMonth > 12 { newMonth = 1; newYear += 1 } else if newMonth < 1 { newMonth = 12; newYear -= 1 }
        let targetID = String(format: "%d-%02d", newYear, newMonth)
        NotificationCenter.default.post(name: .scrollToMonth, object: targetID)
    }
    
    private func extractDaysInMonth(for date: Date) -> [Date?] {
        let calendar = Calendar.current; var days = [Date?]()
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let firstDayOfMonth = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: monthInterval.start) else { return [] }
        let component = calendar.component(.weekday, from: firstDayOfMonth)
        let emptyDaysBefore = (component + 5) % 7
        for _ in 0..<emptyDaysBefore { days.append(nil) }
        let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth)!
        for i in 0..<range.count {
            if let dayDate = calendar.date(byAdding: .day, value: i, to: firstDayOfMonth) { days.append(dayDate) }
        }
        return days
    }
}

// MARK: - 无缝网格分段

private struct MonthGridSection: View {
    let section: MonthSection
    let recordsDict: [Date: ReadingRecord]
    
    private var monthTotalMinutes: Int {
        section.days.compactMap { d -> Int? in
            guard let date = d, let record = recordsDict[Calendar.current.startOfDay(for: date)] else { return nil }
            return Int(record.readingDuration / 60)
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
                        DayCardView(date: date, record: recordsDict[Calendar.current.startOfDay(for: date)])
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
    let recordsDict: [Date: ReadingRecord]
    
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
               let record = recordsDict[cal.startOfDay(for: date)]
            {
                data.append((day, record.readingDuration / 60.0))
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
    let record: ReadingRecord?
    
    @State private var isHovered = false
    
    var body: some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let hasRead = record != nil
        let dateString = "\(calendar.component(.day, from: date))"
        
        let totalSeconds = Int(record?.readingDuration ?? 0)
        let dailyMinutes = totalSeconds > 0 ? max(1, totalSeconds / 60) : 0
        let isCelebration = dailyMinutes > 50
        let bookTitle = record?.book?.title
        
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
            
            if hasRead, let title = bookTitle {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary.opacity(0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .offset(y: 4)
            }
            
        }
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(isHovered ? 0.2 : 0.05), lineWidth: isHovered ? 2 : 1))
        .shadow(color: Color.black.opacity(isHovered ? 0.12 : 0.0), radius: isHovered ? 12 : 0, y: isHovered ? 6 : 0)
        .scaleEffect(isHovered ? 1.05 : 1.0)
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

#Preview("月度记录") {
    MonthlyRecordView()
        .frame(width: 1000, height: 750)
        .modelContainer(PreviewData.shared)
}
#endif
