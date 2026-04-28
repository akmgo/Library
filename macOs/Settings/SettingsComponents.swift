import SwiftUI
import SwiftData

// MARK: - 今日阅读进度指环

/// 轻量化的圆环进度图表，常驻于 macOS 和 iOS 的侧边栏/底部区域。
///
/// **架构特性：**
/// 该组件通过跨组存储 `@AppStorage("dailyReadingGoal")` 即时获取用户在设置页面调整的日标预期。
/// 然后直接读取并累加 SwiftData 中属于今日的记录时长。一旦达标，会将圆环化为火焰图标。
struct DailyProgressRingView: View {
    @Query var allRecords: [ReadingRecord]
    @AppStorage("dailyReadingGoal", store: SharedDatabase.shared.sharedDefaults)
    private var dailyReadingGoal: Int = 30
    
    // 计算今天总共读了多少分钟
    var todayMinutes: Int {
        let calendar = Calendar.current
        let todayRecords = allRecords.filter { calendar.isDateInToday($0.date) }
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

#if os(macOS)
import SwiftUI

// MARK: - 设置面板 UI 原子组件

/// 渲染设置页面左侧带高亮图标和副标题的模块大标题行。
struct SettingsHeaderRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(iconColor)
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(.primary)
                Text(subtitle).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
            }
        }
    }
}

// MARK: - 设置面板 UI 原子组件 (全局复用)

/// 渲染一行设置选项，左侧包含带背景底座的图标与文案，右侧开口用于承载控件。
struct SettingsControlRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let control: Content
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(iconColor).frame(width: 28, height: 28)
                Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(.primary)
                Text(subtitle).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
            }
            
            Spacer(minLength: 16)
            control
        }
        .padding(.vertical, 6)
    }
}
#endif
