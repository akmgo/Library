#if os(macOS)
import AppKit
import Charts
import SwiftData
import SwiftUI

// MARK: - 数据模型与滚动监听器

private struct MonthSection: Identifiable { let id: String; let year: Int; let month: Int; let days: [Date?] }

private struct ScrollBoundsKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct MonthlyRecordView: View {
    @Query var allRecords: [ReadingRecord]
    let daysOfWeek = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    
    @State private var cachedRecordsDict: [Date: ReadingRecord] = [:]
    @State private var cachedSections: [MonthSection] = []
    
    @State private var visibleYear: Int = Calendar.current.component(.year, from: Date())
    @State private var visibleMonth: Int = Calendar.current.component(.month, from: Date())
    
    var body: some View {
        GeometryReader { mainGeo in
            ZStack(alignment: .top) {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()
                                
                Circle()
                    .fill(Color.indigo.opacity(0.08))
                    .blur(radius: 120)
                    .frame(width: 800, height: 800)
                    .offset(x: -200, y: -300)
                // ================= 1. 底层无缝连续滚动区 =================
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
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
                        .padding(.bottom, 200)
                    }
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
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { proxy.scrollTo(targetID, anchor: .top) }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .scrollToToday)) { _ in
                        let calendar = Calendar.current
                        let targetID = String(format: "%d-%02d", calendar.component(.year, from: Date()), calendar.component(.month, from: Date()))
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { proxy.scrollTo(targetID, anchor: .top) }
                    }
                }
                
                // ================= 2. 顶层原生 Header =================
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        // 左侧：年月标题 (固定宽度以保持平衡)
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Text(String(format: "%d年", visibleYear))
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)
                            Text("\(visibleMonth)月")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 170, alignment: .leading)
                                            
                        // ✨ 中间：新增的当月阅读时长动态曲线图
                        MonthlySparklineView(year: visibleYear, month: visibleMonth, recordsDict: cachedRecordsDict)
                            .frame(height: 36) // 严格控制高度，不破坏原有比例
                            .padding(.horizontal, 20)
                                            
                        // 右侧：控制按钮 (固定宽度以保持平衡)
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
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 50)
                    .padding(.bottom, 16)
                    
                    HStack(spacing: 20) {
                        ForEach(daysOfWeek, id: \.self) { day in
                            Text(day).font(.system(size: 13, weight: .bold)).foregroundColor(.secondary.opacity(0.6)).frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 40).padding(.bottom, 16)
                    Divider()
                }
                .background(
                    Color.clear
                        .background(.ultraThinMaterial)
                        .opacity(0.85)
                )
                .ignoresSafeArea(edges: .top)
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear { self.buildContinuousData() }
        .onChange(of: allRecords) { _, _ in self.buildContinuousData() }
    }
    
    // MARK: - 引擎逻辑 (保持不变)

    private func buildContinuousData() {
        let calendar = Calendar.current
        var dict = [Date: ReadingRecord]()
        for record in allRecords {
            dict[calendar.startOfDay(for: record.date ?? Date())] = record
        }
        cachedRecordsDict = dict
        
        let today = Date(); var sections = [MonthSection]()
        for offset in -12 ... 12 {
            if let monthDate = calendar.date(byAdding: .month, value: offset, to: today) {
                let year = calendar.component(.year, from: monthDate); let month = calendar.component(.month, from: monthDate)
                let id = String(format: "%d-%02d", year, month); let days = extractDaysInMonth(for: monthDate)
                sections.append(MonthSection(id: id, year: year, month: month, days: days))
            }
        }
        cachedSections = sections
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { NotificationCenter.default.post(name: .scrollToToday, object: nil) }
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
        for _ in 0..<emptyDaysBefore {
            days.append(nil)
        }
        let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth)!
        for i in 0..<range.count {
            if let dayDate = calendar.date(byAdding: .day, value: i, to: firstDayOfMonth) { days.append(dayDate) }
        }
        return days
    }
}

// MARK: - 无缝网格分段 (带月度数据统计)

private struct MonthGridSection: View {
    let section: MonthSection
    let recordsDict: [Date: ReadingRecord]
    
    /// 预计算本月总时长
    private var monthTotalMinutes: Int {
        section.days.compactMap { d -> Int? in
            guard let date = d, let record = recordsDict[Calendar.current.startOfDay(for: date)] else { return nil }
            return Int(record.readingDuration / 60)
        }.reduce(0, +)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // ✨ 优化 1：月度标题加入微型统计，提升宏观洞察
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

// MARK: - ✨ 顶部玻璃区专属：月度动态微缩曲线图

private struct MonthlySparklineView: View {
    let year: Int
    let month: Int
    let recordsDict: [Date: ReadingRecord]
    
    @State private var chartData: [(day: Int, minutes: Double)] = []
    
    var body: some View {
        Chart(chartData, id: \.day) { item in
            // 平滑曲线
            LineMark(
                x: .value("Day", item.day),
                y: .value("Minutes", item.minutes)
            )
            .interpolationMethod(.catmullRom) // 让生硬的折线变平滑
            .foregroundStyle(Color.indigo.gradient)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            
            // 曲线下方的渐变面积遮罩，提升质感
            AreaMark(
                x: .value("Day", item.day),
                y: .value("Minutes", item.minutes)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.indigo.opacity(0.3), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartXAxis(.hidden) // 隐藏杂乱的坐标轴
        .chartYAxis(.hidden)
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
                data.append((day, 0)) // 没读书的日子记为 0
            }
        }
        chartData = data
    }
}

// MARK: - ✨ 高定方形数据卡片 (书名绝对居中版)

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
        let isCelebration = dailyMinutes >= 60
        let bookTitle = record?.book?.title
        
        let heatOpacity = min(Double(dailyMinutes) / 120.0, 1.0)
        
        ZStack {
            // 1. 底色
            Rectangle()
                .fill(hasRead ? Color(nsColor: .controlBackgroundColor) : Color.secondary.opacity(0.03))
            
            // 2. 底部能量潮汐条
            if hasRead {
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(
                            isCelebration ?
                                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [.blue.opacity(0.5), .indigo.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(height: 8 + (32 * heatOpacity))
                        .shadow(color: (isCelebration ? Color.pink : Color.blue).opacity(0.4), radius: 8, y: -4)
                }
            }
            
            // 3. 顶部信息栏 (悬浮贴顶)
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
                            if isCelebration { Image(systemName: "sparkles").font(.system(size: 9)) }
                            Text("\(dailyMinutes)m")
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(isCelebration ? .orange : .secondary)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                    }
                }
                .padding(10)
                Spacer() // 把顶部信息推上去，不影响下面的绝对居中
            }
            
            // 4. ✨ 绝对居中的书名区
            if hasRead, let title = bookTitle {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary.opacity(0.8))
                    .lineLimit(2) // 允许一行或两行
                    .multilineTextAlignment(.center) // 文字自身对齐方式
                    .padding(.horizontal, 12)
                    // ZStack 默认将子视图放在正中心。
                    // 稍微往下偏移 4pt，避开顶部的日期和时长，视觉上更加平衡
                    .offset(y: 4)
            }
            
            // 5. 悬停展露封面彩蛋
            if hasRead, let coverData = record?.book?.coverData, isHovered {
                ZStack {
                    Color.black.opacity(0.7)
                    LocalCoverView(coverData: coverData, fallbackTitle: bookTitle ?? "")
                        .aspectRatio(2 / 3, contentMode: .fit)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
                    
                    Text("\(dailyMinutes) 分钟")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        .offset(y: 45)
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                .zIndex(100)
            }
        }
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(isHovered ? 0.2 : 0.05), lineWidth: isHovered ? 2 : 1))
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = h }
            if h && hasRead { NSCursor.pointingHand.push() } else { NSCursor.pop() }
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
