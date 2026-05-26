#if os(iOS)
import SwiftUI

// MARK: - 📊 核心数据大盘 (纯粹渲染版)

struct MobileDashboardCard: View {
    let weekCount: Int
    let monthlyDays: Int
    let todayMinutes: Int
    let dailyGoal: Int
    let yearlyCount: Int
    let yearTarget: Int
    let totalFinished: Int
    let totalLibrary: Int

    let monthTarget = 30
    let weekTarget = 7

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack {
                    Text("时光轨迹").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "target").foregroundColor(.pink)
                }
                HStack(alignment: .center, spacing: 0) {
                    AppMicroMetric(title: "本周打卡", current: weekCount, target: weekTarget, color: .pink, icon: "flame.fill")
                    Spacer()
                    AppMicroMetric(title: "本月历程", current: monthlyDays, target: monthTarget, color: .mint, icon: "calendar")
                    Spacer()
                    AppMicroMetric(title: "今日时长", current: todayMinutes, target: dailyGoal, color: .blue, icon: "clock.fill")
                    Spacer()
                    AppMicroMetric(title: "年度阅卷", current: yearlyCount, target: yearTarget, color: .cyan, icon: "book.closed.fill")
                    Spacer()
                    AppMicroMetric(title: "馆藏进度", current: totalFinished, target: max(totalLibrary, 1), color: .indigo, icon: "books.vertical.fill")
                }
                .padding(.horizontal, 2)
                .padding(.vertical, AppSpacing.xs)
            }
        }
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
                Circle().stroke(color.opacity(0.15), lineWidth: 4).frame(width: 44, height: 44)
                Circle().trim(from: 0, to: progress).stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round)).frame(width: 44, height: 44).rotationEffect(.degrees(-90))
                Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundColor(color)
            }
            Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
        }
    }
}

#if DEBUG
private struct PreviewDashboardCard: View {
    var body: some View {
        MobileDashboardCard(
            weekCount: 5, monthlyDays: 18, todayMinutes: 45, dailyGoal: 60,
            yearlyCount: 12, yearTarget: 24, totalFinished: 42, totalLibrary: 60
        )
        .padding()
        .background(AppColors.primaryBackground(for: .light))
    }
}

#Preview("数据大盘") {
    PreviewDashboardCard()
}
#endif


#endif
