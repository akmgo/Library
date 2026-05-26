import SwiftUI
import SwiftData

// MARK: - 今日阅读进度指环

/// 轻量化的圆环进度图表，常驻于 macOS 和 iOS 的侧边栏/底部区域。
///
/// **架构特性：**
/// 该组件通过跨组存储 `@AppStorage("dailyMinutesGoal")` 即时获取用户在设置页面调整的日标预期。
/// 然后直接读取并累加 SwiftData 中属于今日的记录时长。一旦达标，会将圆环化为火焰图标。
struct DailyProgressRingView: View {
    @Query var allRecords: [ReadingSession]
    @AppStorage("dailyMinutesGoal", store: SharedDatabase.shared.sharedDefaults)
    private var dailyMinutesGoal: Int = 30
    
    // 计算今天总共读了多少分钟
    var todayMinutes: Int {
        let calendar = Calendar.current
        let todayRecords = allRecords.filter { calendar.isDateInToday($0.date) }
        let totalSeconds = todayRecords.reduce(0) { $0 + Int($1.duration) }
        return totalSeconds / 60
    }
    
    var body: some View {
        let progress = min(Double(todayMinutes) / Double(dailyMinutesGoal), 1.0)
        let isCompleted = todayMinutes >= dailyMinutesGoal
        
        ZStack {
            // 背景底环 (使用四级灰阶，跨端跨主题自适应)
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 3)
            
            // 进度走环 (原生薄荷绿 / 原生橘色)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(isCompleted ? Color.orange : Color.mint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            
            // 中心内容：没达标显示数字，达标变成火焰
            if isCompleted {
                Text("🔥")
                    .font(.system(size: 11))
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text("\(todayMinutes)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 20, height: 20)
        .help("今日阅读: \(todayMinutes) / \(dailyMinutesGoal) 分钟")
    }
}
