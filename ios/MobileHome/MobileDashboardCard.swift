#if os(iOS)
import SwiftUI

// MARK: - 📊 核心数据大盘 (纯粹渲染版)

struct MobileDashboardCard: View {
    // 彻底抛弃 @Query 和 @State，全部由外部传入算好的最终数值
    let weekCount: Int
    let monthlyDays: Int
    let todayMinutes: Int
    let dailyGoal: Int
    let yearlyCount: Int
    let yearTarget: Int
    let totalFinished: Int
    let totalLibrary: Int
    
    // 固定目标值
    let monthTarget = 30
    let weekTarget = 7
    
    var body: some View {
        GroupBox {
            // ================= 五大圆环看板 =================
            HStack(alignment: .center, spacing: 0) {
                // 1. 本周
                AppMicroMetric(title: "本周打卡", current: weekCount, target: weekTarget, color: .pink, icon: "flame.fill")
                Spacer()
                
                // 2. 本月
                AppMicroMetric(title: "本月历程", current: monthlyDays, target: monthTarget, color: .mint, icon: "calendar")
                Spacer()
                
                // 3. 今日阅读时长
                AppMicroMetric(title: "今日时长", current: todayMinutes, target: dailyGoal, color: .blue, icon: "clock.fill")
                Spacer()
                
                // 4. 年度
                AppMicroMetric(title: "年度阅卷", current: yearlyCount, target: yearTarget, color: .cyan, icon: "book.closed.fill")
                Spacer()
                
                // 5. 馆藏
                AppMicroMetric(title: "馆藏进度", current: totalFinished, target: max(totalLibrary, 1), color: .indigo, icon: "books.vertical.fill")
            }
            .padding(.horizontal, 2)
            .padding(.vertical, AppSpacing.xs)
        } label: {
            HStack {
                Text("时光轨迹").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "target").foregroundColor(.pink)
            }
        }
        // 删除了所有的 .onAppear 和 .onChange，卡片变得无比轻盈
    }
}

/// 辅助子组件保持不变
private struct AppMicroMetric: View {
    let title: String; let current: Int; let target: Int; let color: Color; let icon: String
    var body: some View {
        let safeTarget = max(Double(target), 1.0)
        let progress = min(Double(current) / safeTarget, 1.0)
        
        VStack(spacing: AppSpacing.xs) {
            ZStack {
                Circle().stroke(color.opacity(0.15), lineWidth: 5.0)
                Circle()
                    .trim(from: 0, to: max(progress, 0.001))
                    .stroke(color.gradient, style: StrokeStyle(lineWidth: 5.0, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundColor(color)
            }
            .frame(width: 48, height: 48)
            
            VStack(spacing: 2) {
                Text("\(current)/\(target)").font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundColor(.primary)
                Text(title).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
            }
        }
    }
}

#Preview("手机端数据大盘 - 时光轨迹") {
    ScrollView {
        MobileDashboardCard(
            weekCount: 5,
            monthlyDays: 14,
            todayMinutes: 45,
            dailyGoal: 60,
            yearlyCount: 12,
            yearTarget: 50,
            totalFinished: 28,
            totalLibrary: 104
        ).padding()
    }.background(Color(UIColor.systemGroupedBackground))
}
#endif
