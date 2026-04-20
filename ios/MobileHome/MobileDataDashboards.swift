#if os(iOS)
import SwiftUI
import SwiftData
import Charts

// MARK: - 📊 核心数据大盘

/// 完美复刻桌面端圆环看板的 iOS 端宏观数据仪表盘。
///
/// **数据聚合逻辑：**
/// 提供四个维度的数据透视：本周打卡天数、本月历程、年度通关本数、总馆藏目标进度。
/// 底部横穿一条进度条呈现当天的“每日沉浸阅读时长”达标比率。
struct MobileDashboardCard: View {
    let allBooks: [Book]
    let allRecords: [ReadingRecord]
    
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]
    
    /// 动态提取目标，查不到给个兜底值
    var dailyGoal: Int { configs.first?.dailyReadingGoal ?? 30 }
    var yearTarget: Int { configs.first?.yearlyBookGoal ?? 50 }
    
    let monthTarget = 30
    let weekTarget = 7
    
    @State private var yearlyCount = 0
    @State private var monthlyDays = 0
    @State private var weekCount = 0
    @State private var totalFinished = 0
    @State private var totalLibrary = 0
    @State private var todayMinutes = 0
    
    var body: some View {
        GroupBox {
            VStack(spacing: 24) {
                // ================= 顶部：四大圆环看板 =================
                HStack(alignment: .center) {
                    AppMicroMetric(title: "本周打卡", current: weekCount, target: weekTarget, color: .pink, icon: "flame.fill")
                    Spacer()
                    AppMicroMetric(title: "本月历程", current: monthlyDays, target: monthTarget, color: .mint, icon: "calendar")
                    Spacer()
                    AppMicroMetric(title: "年度阅卷", current: yearlyCount, target: yearTarget, color: .cyan, icon: "book.closed.fill")
                    Spacer()
                    AppMicroMetric(title: "馆藏进度", current: totalFinished, target: max(totalLibrary, 1), color: .indigo, icon: "books.vertical.fill")
                }
                
                // ================= 底部：今日阅读进度 =================
                VStack(spacing: 8) {
                    HStack(alignment: .bottom) {
                        Label("今日阅读", systemImage: "book.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if todayMinutes >= dailyGoal {
                            Text("🎉 目标达成")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.blue)
                        } else {
                            Text("\(todayMinutes) / \(dailyGoal) 分钟")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    let safeProgress = min(max(Double(todayMinutes) / Double(dailyGoal), 0.0), 1.0)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.15))
                            Capsule()
                                .fill(Color.blue.gradient)
                                .frame(width: geo.size.width * CGFloat(safeProgress))
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: safeProgress)
                        }
                    }.frame(height: 8)
                }
            }
            .padding(.top, 4)
        } label: {
            HStack {
                Text("时光轨迹").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "target").foregroundColor(.pink)
            }
        }
        .onAppear { calculateStats() }
        .onChange(of: allRecords) { _, _ in calculateStats() }
        .onChange(of: allBooks) { _, _ in calculateStats() }
    }
    
    private func calculateStats() {
        let cal = Calendar.current; let today = Date()
        yearlyCount = allBooks.filter { $0.status == .finished && cal.component(.year, from: $0.endTime ?? .distantFuture) == cal.component(.year, from: today) }.count
        monthlyDays = Set(allRecords.filter { cal.isDate($0.date ?? .distantPast, equalTo: today, toGranularity: .month) }.map { cal.component(.day, from: $0.date!) }).count
        totalFinished = allBooks.filter { $0.status == .finished }.count
        totalLibrary = allBooks.count
        todayMinutes = allRecords.filter { cal.isDate($0.date ?? .distantPast, inSameDayAs: today) }.reduce(0) { $0 + Int($1.readingDuration) } / 60
        
        var tempCount = 0
        if let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) {
            for i in 0..<7 {
                if let d = cal.date(byAdding: .day, value: i, to: startOfWeek), allRecords.contains(where: { cal.isDate($0.date ?? .distantPast, inSameDayAs: d) }) { tempCount += 1 }
            }
        }
        weekCount = tempCount
    }
}

/// 辅助子组件：用于绘制仪表盘上的微型状态带发光圆环
private struct AppMicroMetric: View {
    let title: String; let current: Int; let target: Int; let color: Color; let icon: String
    var body: some View {
        let safeTarget = max(Double(target), 1.0)
        let progress = min(Double(current) / safeTarget, 1.0)
        
        VStack(spacing: 8) {
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
#endif
