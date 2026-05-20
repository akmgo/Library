#if os(iOS)
import SwiftUI
import SwiftData
import Charts

// MARK: - 🗓️ 核心月度记录视图 (原生秒开版)

struct MobileMonthlyRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    // 缓存数据源
    @State private var cachedRecordsDict: [Date: TimeInterval] = [:]
    @State private var cachedSections: [MonthSection] = []
    
    let daysOfWeek = ["一", "二", "三", "四", "五", "六", "日"]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 32, pinnedViews: [.sectionHeaders]) {
                    ForEach(cachedSections) { section in
                        Section(header: monthSectionHeader(section)) {
                            monthGrid(section: section)
                        }
                        .id(section.id)
                    }
                }
                .padding(.horizontal, 16)
                // 因为没有了悬浮 Header，顶部留白可以大大缩减，更紧凑
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            // 完全摒弃 opacity 和 offset 动画，原生直出
            .onAppear {
                buildDataAndScroll(proxy: proxy)
            }
        }
    }
    
    // MARK: - ✨ UI 组件模块
    
    private func monthSectionHeader(_ section: MonthSection) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text("\(String(section.year))年")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
            Text("\(section.month)月")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.primary)
            
            Spacer()
            
            // 计算该月总时长
            let totalMins = section.days.compactMap { d -> Int? in
                guard let date = d, let duration = cachedRecordsDict[Calendar.current.startOfDay(for: date)] else { return nil }
                return Int(duration / 60)
            }.reduce(0, +)
            
            if totalMins > 0 {
                Text("\(totalMins / 60)h \(totalMins % 60)m")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundColor(.indigo)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.indigo.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 12)
        .background(AppColors.primaryBackground(for: colorScheme)) // 吸顶时不透明
    }
    
    private func monthGrid(section: MonthSection) -> some View {
        VStack(spacing: 12) {
            // 星期表头
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary.opacity(0.5)).frame(maxWidth: .infinity)
                }
            }
            
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<section.days.count, id: \.self) { index in
                    if let date = section.days[index] {
                        MobileDayCardView(
                            date: date,
                            duration: cachedRecordsDict[Calendar.current.startOfDay(for: date)]
                        )
                    } else {
                        Color.clear.frame(height: 70)
                    }
                }
            }
        }
    }
    
    // MARK: - ⚙️ 数据引擎 (瞬间加载与定位)
    
    private func buildDataAndScroll(proxy: ScrollViewProxy) {
        Task { @MainActor in
            let calendar = Calendar.current
            let records = (try? modelContext.fetch(FetchDescriptor<ReadingSession>())) ?? []
            
            var dict = [Date: TimeInterval]()
            for r in records { dict[calendar.startOfDay(for: r.date), default: 0] += r.duration }
            self.cachedRecordsDict = dict
            
            // 动态推算展示区间（从最早的一条记录开始，一直到下个月）
            let today = Date()
            let earliestDate = records.map { $0.date }.min() ?? calendar.date(byAdding: .month, value: -6, to: today)!
            
            var currentMonthDate = calendar.date(from: calendar.dateComponents([.year, .month], from: earliestDate))!
            let endMonthDate = calendar.date(byAdding: .month, value: 1, to: calendar.date(from: calendar.dateComponents([.year, .month], from: today))!)!
            
            var sections = [MonthSection]()
            
            while currentMonthDate <= endMonthDate {
                let year = calendar.component(.year, from: currentMonthDate)
                let month = calendar.component(.month, from: currentMonthDate)
                sections.append(MonthSection(
                    id: String(format: "%d-%02d", year, month),
                    year: year, month: month,
                    days: extractDays(for: currentMonthDate)
                ))
                // 推进到下一个月
                currentMonthDate = calendar.date(byAdding: .month, value: 1, to: currentMonthDate)!
            }
            self.cachedSections = sections
            
            // 先获取当前月的 ID
            let currentID = String(format: "%d-%02d", calendar.component(.year, from: today), calendar.component(.month, from: today))
            
            // 给 SwiftUI 一个极短的运行周期来挂载刚刚赋值的 sections 视图树
            try? await Task.sleep(nanoseconds: 50_000_000)
            
            // ✨ 原生直出：瞬间、无动画地把当前月份卡在屏幕最顶部 (anchor: .top)
            proxy.scrollTo(currentID, anchor: .top)
        }
    }
    
    private func extractDays(for date: Date) -> [Date?] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: date),
              let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: date)) else { return [] }
        let weekday = cal.component(.weekday, from: firstDay)
        let offset = (weekday + 5) % 7
        var days: [Date?] = Array(repeating: nil, count: offset)
        for i in 0..<range.count { days.append(cal.date(byAdding: .day, value: i, to: firstDay)) }
        return days
    }
}

// MARK: - ✨ 单日卡片 (精准应用 VisualEngines)

struct MobileDayCardView: View {
    let date: Date
    let duration: TimeInterval?
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isPressed = false
    
    var body: some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(date)
        let mins = Int((duration ?? 0) / 60)
        
        ZStack {
            // 底板
            RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous)
                .fill(duration != nil ? AppColors.secondaryBackground(for: colorScheme) : Color.secondary.opacity(0.04))
            
            // ✨ 视觉引擎：热力柱渲染
            if duration != nil, mins > 0 {
                VStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(VisualEngines.ReadingHeatmap.gradient(for: mins))
                        // 移动端高度适配：在 Mac 规范基础上乘以 0.8
                        .frame(height: VisualEngines.ReadingHeatmap.height(for: mins) * 0.8)
                        .padding(4)
                        .shadow(color: VisualEngines.ReadingHeatmap.shadowColor(for: mins).opacity(0.3), radius: 4, y: 2)
                }
            }
            
            // 日期数字
            VStack {
                HStack {
                    ZStack {
                        if isToday { Circle().fill(Color.red).frame(width: 18, height: 18) }
                        Text("\(cal.component(.day, from: date))")
                            .font(.system(size: 12, weight: isToday ? .bold : .medium, design: .rounded))
                            .foregroundColor(isToday ? .white : (duration != nil ? .primary : .secondary.opacity(0.4)))
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(6)
        }
        .frame(height: 72)
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .onTapGesture {
            if duration != nil {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring()) { isPressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { withAnimation { isPressed = false } }
            }
        }
    }
}

private struct MonthSection: Identifiable {
    let id: String; let year: Int; let month: Int; let days: [Date?]
}
#endif
