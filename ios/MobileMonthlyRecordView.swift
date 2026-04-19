#if os(iOS)
import SwiftData
import SwiftUI

struct MobileMonthlyRecordView: View {
    let initialMonthTitle: String
    @Query var allRecords: [ReadingRecord]
    
    @State private var currentDate: Date
    @State private var slideDirection: AnyTransition = .opacity
    let daysOfWeek = ["一", "二", "三", "四", "五", "六", "日"]
    
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
        // 如果一天有多条记录，这里默认展示第一条对应的书籍封面
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
        
        let dateFormatter: DateFormatter = {
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; return df
        }()
        
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
                    // 左侧：时长统计 (智能换算小时与分钟)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("专注时长").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary)
                        let totalMinutes = Int(totalDuration / 60)
                        if totalMinutes >= 60 {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(totalMinutes / 60)").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(.indigo)
                                    .contentTransition(.numericText())
                                Text("时").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                                Text("\(totalMinutes % 60)").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(.indigo)
                                    .contentTransition(.numericText())
                                Text("分").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                            }
                        } else {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(totalMinutes)").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(.indigo)
                                    .contentTransition(.numericText())
                                Text("分钟").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider().frame(height: 36).opacity(0.5)
                    
                    // 右侧：打卡天数统计
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("打卡天数").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary)
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(daysCount)").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(.teal)
                                .contentTransition(.numericText())
                            Text("天").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(20)
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground).opacity(0.8)
                        .background(.ultraThinMaterial)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
                .padding(.horizontal, 20)
                
                // ================= 3. 移动端日历网格 (支持左右滑动) =================
                VStack(spacing: 16) {
                    HStack(spacing: 0) {
                        ForEach(daysOfWeek, id: \.self) { day in
                            Text(day).font(.system(size: 13, weight: .bold)).foregroundColor(.secondary).frame(maxWidth: .infinity)
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
                                if value.translation.width < -threshold {
                                    changeMonth(by: 1) // 向左划，去下个月
                                } else if value.translation.width > threshold {
                                    changeMonth(by: -1) // 向右划，去上个月
                                }
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
    
    // MARK: - 辅助方法
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

// MARK: - 📱 单日微型画廊卡片
private struct MobileDayCardView: View {
    let date: Date
    let record: ReadingRecord?
    
    var body: some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let hasRead = record != nil
        let dateString = "\(calendar.component(.day, from: date))"
        
        ZStack {
            // 1. 极简呼吸感底板
            if !hasRead {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.6))
                    // 如果今天是未打卡，给一个轻微的红色边框提示
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isToday ? Color.red.opacity(0.4) : Color.primary.opacity(0.03), lineWidth: isToday ? 1.5 : 1)
                    )
            }
            
            // 2. 封面渲染
            if let book = record?.book {
                let safeTitle = book.title ?? "未知书名"
                LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 3, y: 2)
            } else if hasRead { // 有记录但没关联封面时的降级兜底
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.teal.opacity(0.15))
                    .overlay(Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)).foregroundColor(.teal))
            }
            
            // 3. 日期数字渲染
            if hasRead {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            if isToday {
                                // 今天的已打卡红色胶囊底座
                                Capsule()
                                    .fill(Color.red.gradient)
                                    .frame(width: 18, height: 14)
                                    .shadow(color: Color.red.opacity(0.3), radius: 2, y: 1)
                            }
                            Text(dateString)
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                // 如果不是今天，加一点黑色阴影防止被浅色封面吞没
                                .shadow(color: isToday ? .clear : .black.opacity(0.6), radius: 1, y: 1)
                                .offset(y: isToday ? 0 : 0)
                        }
                    }
                }
                .padding(4)
            } else {
                ZStack {
                    if isToday {
                        Text(dateString)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(.red)
                    } else {
                        Text(dateString)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
            }
        }
        .aspectRatio(0.7, contentMode: .fit)
        // 增加微小的触控反馈
        .onTapGesture {
            if hasRead {
                let impact = UIImpactFeedbackGenerator(style: .soft)
                impact.impactOccurred()
            }
        }
    }
}
#endif
