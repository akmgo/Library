import SwiftUI
import SwiftData

struct DailyProgressRingView: View {
    @Query var allRecords: [ReadingRecord]
    @AppStorage("dailyReadingGoal", store: SharedDatabase.shared.sharedDefaults)
    private var dailyReadingGoal: Int = 30
    
    // 计算今天总共读了多少分钟
    var todayMinutes: Int {
        let calendar = Calendar.current
        let todayRecords = allRecords.filter { calendar.isDateInToday($0.date ?? Date()) }
        let totalSeconds = todayRecords.reduce(0) { $0 + Int($1.readingDuration) }
        return totalSeconds / 60
    }
    
    var body: some View {
        let progress = min(Double(todayMinutes) / Double(dailyReadingGoal), 1.0)
        let isCompleted = todayMinutes >= dailyReadingGoal
        
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
        .help("今日阅读: \(todayMinutes) / \(dailyReadingGoal) 分钟")
    }
}
