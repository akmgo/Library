#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 数据模型与滚动监听器

struct MonthSection: Identifiable {
    let id: String; let year: Int; let month: Int; let days: [Date?]
}

struct ScrollBoundsKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - 🗓️ 月度记录主视图

/// iOS 端的按月打卡热力图及记录大盘。
///
/// **交互与架构：**
/// 该视图构建了一个前后跨越 25 个月的“无缝无限滚动视图”。
/// 顶部悬浮的玻璃 Header 会通过底层的 `ScrollBoundsKey` 实时嗅探当前位于屏幕中央的月份，
/// 从而动态刷新顶部的年月标题以及月度趋势曲线图。
struct MobileMonthlyRecordView: View {
    let initialMonthTitle: String
    @Query var allRecords: [ReadingRecord]
    
    @State private var currentDate: Date
    @State private var slideDirection: AnyTransition = .opacity
    let daysOfWeek = ["一", "二", "三", "四", "五", "六", "日"]
    
    @State private var cachedRecordsDict: [Date: ReadingRecord] = [:]
    @State private var cachedSections: [MonthSection] = []
    
    @State private var visibleYear: Int = Calendar.current.component(.year, from: Date())
    @State private var visibleMonth: Int = Calendar.current.component(.month, from: Date())
    
    init(monthTitle: String, records: [ReadingRecord] = []) {
        self.initialMonthTitle = monthTitle
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        let date = formatter.date(from: monthTitle) ?? Date()
        _currentDate = State(initialValue: date)
    }
    
    private var currentMonthRecords: [ReadingRecord] {
        let cal = Calendar.current
        return allRecords.filter { cal.isDate($0.date ?? Date.distantPast, equalTo: currentDate, toGranularity: .month) }
    }
    
    private var recordsDictionary: [String: ReadingRecord] {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        var dict = [String: ReadingRecord]()
        for record in currentMonthRecords {
            let key = formatter.string(from: record.date ?? Date.distantPast)
            if dict[key] == nil { dict[key] = record }
        }
        return dict
    }
    
    var totalDuration: TimeInterval { currentMonthRecords.reduce(0) { $0 + ($1.readingDuration) } }
    var daysCount: Int { recordsDictionary.keys.count }
    
    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)
        let daysInMonth = extractDaysInMonth(for: currentDate)
        let dateFormatter: DateFormatter = { let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; return df }()
        
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // ================= 1. 顶部控制台 =================
                HStack(alignment: .center) {
                    Text(formattedYearMonth(currentDate))
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                        .id("title-\(formattedYearMonth(currentDate))")
                        .transition(slideDirection)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        monthButton(icon: "chevron.left") { changeMonth(by: -1) }
                        monthButton(icon: "chevron.right") { changeMonth(by: 1) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // ================= 2. 月度高定统计面板 =================
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("专注时长").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary)
                        let totalMinutes = Int(totalDuration / 60)
                        if totalMinutes >= 60 {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(totalMinutes / 60)").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(.indigo).contentTransition(.numericText())
                                Text("时").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                                Text("\(totalMinutes % 60)").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(.indigo).contentTransition(.numericText())
                                Text("分").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                            }
                        } else {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(totalMinutes)").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(.indigo).contentTransition(.numericText())
                                Text("分钟").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider().frame(height: 36).opacity(0.5)
                    
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("打卡天数").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary)
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(daysCount)").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(.teal).contentTransition(.numericText())
                            Text("天").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(20)
                .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.8).background(.ultraThinMaterial))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
                .padding(.horizontal, 20)
                
                // ================= 3. 移动端日历网格 (支持左右滑动) =================
                VStack(spacing: 16) {
                    HStack(spacing: 0) {
                        ForEach(daysOfWeek, id: \.self) { day in
                            Text(day).font(.system(size: 13, weight: .bold)).foregroundColor(.secondary.opacity(0.6)).frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(0..<daysInMonth.count, id: \.self) { index in
                            if let date = daysInMonth[index] {
                                let dayString = dateFormatter.string(from: date)
                                let dayRecord = recordsDictionary[dayString]
                                MobileDayCardView(date: date, record: dayRecord)
                            } else {
                                Color.clear.aspectRatio(0.7, contentMode: .fit)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .id(formattedYearMonth(currentDate))
                    .transition(slideDirection)
                    // ✨ 加入手势：左右滑动丝滑切换月份
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                let threshold: CGFloat = 40
                                if value.translation.width < -threshold { changeMonth(by: 1) }
                                else if value.translation.width > threshold { changeMonth(by: -1) }
                            }
                    )
                }
            }
            .padding(.bottom, 60)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("月度梳理")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - 内部控制方法
    
    private func monthButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light); impact.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 36, height: 36)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .foregroundColor(.primary)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private func formattedYearMonth(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy年M月"; return formatter.string(from: date)
    }
    
    private func changeMonth(by value: Int) {
        let moveInEdge: Edge = value > 0 ? .trailing : .leading
        let moveOutEdge: Edge = value > 0 ? .leading : .trailing
        slideDirection = .asymmetric(insertion: .move(edge: moveInEdge).combined(with: .opacity), removal: .move(edge: moveOutEdge).combined(with: .opacity))
        
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: currentDate) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { currentDate = newDate }
        }
    }
    
    private func extractDaysInMonth(for date: Date) -> [Date?] {
        let calendar = Calendar.current; var days = [Date?]()
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let firstDayOfMonth = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: monthInterval.start) else { return [] }
        // 修正周一为第一天
        var component = calendar.component(.weekday, from: firstDayOfMonth) - 2
        if component < 0 { component += 7 }
        
        for _ in 0..<component { days.append(nil) }
        let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth)!
        for i in 0..<range.count { if let dayDate = calendar.date(byAdding: .day, value: i, to: firstDayOfMonth) { days.append(dayDate) } }
        return days
    }
}
#endif
