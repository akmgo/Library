#if os(macOS)
import AppKit
import Charts
import SwiftData
import SwiftUI

// MARK: - 数据模型与滚动监听器

/// 描述按月聚合的日历切片数据结构。
///
/// 作为一个滚动单元，它包含了该月所属的年月以及在 UI 上排列所需的每日日期数组。
/// - 注意: 为了兼容每月第一天不是周一的情况，数组头部可能包含用于排版占位的 `nil`。
private struct MonthSection: Identifiable {
    let id: String
    let year: Int
    let month: Int
    let days: [Date?]
}

/// 滚动锚点位置搜集器。
///
/// 利用 SwiftUI 的视图首选项 (`PreferenceKey`) 机制，
/// 收集滚动视图中每个 `MonthGridSection` 相对于全局屏幕的真实物理坐标 (`CGRect`)。
/// 随后可在上层视图中根据这些坐标，实时判断哪个月份正处于屏幕中央。
private struct ScrollBoundsKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - 🗓️ 核心月度记录视图

/// macOS 端专属的按月打卡统计热力视图。
///
/// **交互与视觉特性：**
/// 1. **全景连续滚动**：构建了前后跨越共 25 个月的无缝日历瀑布流。
/// 2. **智能嗅探 Header**：悬浮在顶部的玻璃 Header 能够通过 `ScrollBoundsKey`，精确嗅探并实时刷新当前滚动到屏幕中心的年份与月份。
/// 3. **宏观曲线**：Header 内部嵌套了微型的逐月平滑面积曲线（Sparkline），直观反馈当月读书动能走向。
struct MonthlyRecordView: View {
    /// 拉取全局所有日期的打卡记录以供渲染。
    @Query var allRecords: [ReadingRecord]
    
    let daysOfWeek = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    
    /// 将拉取到的记录以 `日期 -> 记录` 的哈希字典格式进行 O(1) 预缓存，极大提升 UI 网格渲染性能。
    @State private var cachedRecordsDict: [Date: ReadingRecord] = [:]
    /// 预计算并缓存的按月分片的滚动切片结构。
    @State private var cachedSections: [MonthSection] = []
    
    /// 当前位于屏幕视觉正中心的年份。
    @State private var visibleYear: Int = Calendar.current.component(.year, from: Date())
    /// 当前位于屏幕视觉正中心的月份。
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
                                            // 搜集当前这个月度卡片组在屏幕中的物理位置，上报给 PreferenceKey
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
                        // 左侧：年月标题
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Text(String(format: "%d年", visibleYear))
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)
                            Text("\(visibleMonth)月")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 170, alignment: .leading)
                                                    
                        // 中间：当月阅读时长动态曲线图
                        MonthlySparklineView(year: visibleYear, month: visibleMonth, recordsDict: cachedRecordsDict)
                            .frame(height: 36) // 严格控制高度，不破坏原有比例
                            .padding(.horizontal, 20)
                                                    
                        // 右侧：控制按钮
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
    
    // MARK: - 引擎逻辑
    
    /// 将零散记录构建为按月切片的网格视图数据模型。
    ///
    /// 包含以今天为基点，向前和向后各推 `12` 个月，共构建 `25` 个 `MonthSection` 对象。
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
        // 渲染完成后，指令系统自动滚动至当前月份
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { NotificationCenter.default.post(name: .scrollToToday, object: nil) }
    }
    
    /// 计算并发送控制滚动视图跳转的通知。
    ///
    /// - Parameter offset: 月份偏移量。`-1` 为前一月，`1` 为下一月。支持跨年自动进位逻辑。
    private func jumpToMonth(offset: Int) {
        var newMonth = visibleMonth + offset; var newYear = visibleYear
        if newMonth > 12 { newMonth = 1; newYear += 1 } else if newMonth < 1 { newMonth = 12; newYear -= 1 }
        let targetID = String(format: "%d-%02d", newYear, newMonth)
        NotificationCenter.default.post(name: .scrollToMonth, object: targetID)
    }
    
    /// 根据给定月份，抽出该月的 31 天日历，并在数组头部填入 `nil` 占位符以确保周一对齐排版。
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

// MARK: - 无缝网格分段

/// 单个月份瀑布流切片组件。
///
/// 包含左上角的该月总时长汇总统筹，以及下方 7 列等宽的自适应每日卡片网格阵列。
private struct MonthGridSection: View {
    let section: MonthSection
    let recordsDict: [Date: ReadingRecord]
    
    /// 预计算本月度所有日期的总计专注时间 (转换为分钟)。
    private var monthTotalMinutes: Int {
        section.days.compactMap { d -> Int? in
            guard let date = d, let record = recordsDict[Calendar.current.startOfDay(for: date)] else { return nil }
            return Int(record.readingDuration / 60)
        }.reduce(0, +)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 月度标题与微型统计
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
            
            // 7 列自适应排版的日子卡片网格
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<section.days.count, id: \.self) { index in
                    if let date = section.days[index] {
                        DayCardView(date: date, record: recordsDict[Calendar.current.startOfDay(for: date)])
                    } else {
                        Color.clear.frame(height: 110) // 周初空位占位
                    }
                }
            }
        }
    }
}

// MARK: - ✨ 顶部玻璃区专属：月度动态微缩曲线图

/// 一条基于当月打卡时长构建的无 Y 轴面积曲线（Sparkline）。
///
/// 使用 `Swift Charts` 和 `.catmullRom` 插值算法将离散的打卡时间编织成一条充满生命力、
/// 平滑起伏的优雅阅读节奏呼吸线。
private struct MonthlySparklineView: View {
    let year: Int
    let month: Int
    let recordsDict: [Date: ReadingRecord]
    
    @State private var chartData: [(day: Int, minutes: Double)] = []
    
    var body: some View {
        Chart(chartData, id: \.day) { item in
            // 平滑曲线核心描边
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

// MARK: - ✨ 高定方形数据卡片 (每日网格)

/// 承载每日详情的独立信息实体方块。
///
/// 根据当天是否含有 `ReadingRecord` 数据进行动态排版呈现。
/// - **静态展示**：包含当前日期、绝对居中的目标书名，以及底部基于阅读时长动态着色的渐变能量带（时长超一小时则化身橙粉色火种）。
/// - **交互悬停**：当鼠标掠过卡片时，触发柔和的阻尼动画，原卡片盖上黑色透光遮罩并翻出隐藏其中的精美书籍封面图层和具体读时。
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
        // 阅读时间达到 60 分钟将被判定为 `isCelebration` 狂欢模式
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
                Spacer()
            }
            
            // 4. ✨ 绝对居中的书名区
            if hasRead, let title = bookTitle {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary.opacity(0.8))
                    .lineLimit(2) // 允许一行或两行
                    .multilineTextAlignment(.center) // 文字自身对齐方式
                    .padding(.horizontal, 12)
                    // ZStack 默认将子视图放在正中心。稍微往下偏移 4pt 视觉平衡
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

// MARK: - 辅助微件：全局控件按键

/// 标准统一样式的拟物化玻璃圆形点击小钮。
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

// MARK: - 拓展声明：通知事件总线

extension Notification.Name {
    /// 指示 `ScrollView` 跳转至特定月份容器标识的全局通知。
    static let scrollToMonth = Notification.Name("scrollToMonth")
    /// 指示 `ScrollView` 立即无缝滑回当前（今天所在）月度的专属通知。
    static let scrollToToday = Notification.Name("scrollToToday")
}
#endif
