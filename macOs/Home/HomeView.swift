#if os(macOS)
internal import Combine
import SwiftData
import SwiftUI

// MARK: - 🌊 流动书房主页 (Fluid Library)

/// macOS 端专属的应用核心落地页 (Home View)。
///
/// **视觉与架构设计：**
/// 该页面采用“无界流动”的设计哲学，摒弃了传统的侧边栏导航。
/// 它通过顶部毛玻璃悬浮 Header 统揽全局统计（本周/本月/年度/馆藏），
/// 主体区域则使用 `LazyVStack` 以极高的性能渲染在读焦点（Hero）、双周动能、全年热力图
/// 以及想读队列和知识图谱。
struct FluidLibraryHomeView: View {
    /// 全局数据注入
    @Query var allBooks: [Book]
    @Query var allRecords: [ReadingRecord]
    @Query var allExcerpts: [Excerpt]
    
    /// 动画命名空间与父级弹窗控制状态
    let namespace: Namespace.ID
    @Binding var selectedBook: Book?
    @Binding var activeCoverID: String
    
    // 📊 统计数据状态
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]

    var yearTarget: Double { Double(configs.first?.yearlyBookGoal ?? 50) }
    let monthTarget = 30.0
    let weekTarget = 7.0
    
    @State private var yearlyCount: Int = 0
    @State private var monthlyDays: Int = 0
    @State private var weekCount: Int = 0
    
    /// 智能计算当前最活跃在读书籍
    var activeReadingBook: Book? {
        allBooks
            .filter { $0.status == .reading }
            .max { b1, b2 in
                let date1 = b1.readingRecords?.compactMap(\.date).max() ?? b1.startTime ?? .distantPast
                let date2 = b2.readingRecords?.compactMap(\.date).max() ?? b2.startTime ?? .distantPast
                return date1 < date2
            }
    }

    var readBooks: [Book] { allBooks.filter { $0.status == .finished } }
    var wantToReadBooks: [Book] { allBooks.filter { $0.isWantToRead } }
    
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 9 { return "晨光正好，宜卷开新章。" }
        else if hour < 14 { return "午后静谧，在文字中漫步。" }
        else if hour < 19 { return "夕阳西下，且将思想沉淀。" }
        else { return "夜色温润，伴书香入眠。" }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            Circle().fill(Color.indigo.opacity(0.08)).blur(radius: 120).frame(width: 800, height: 800).offset(x: -200, y: -300)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 40) {
                    Spacer().frame(height: 120)
                        
                    // 🌟 Row 1: 核心操作区 (Hero Section)
                    HStack(spacing: 60) {
                        if let heroBook = activeReadingBook {
                            FluidReadingHero(book: heroBook, progress: Double(heroBook.progress), namespace: namespace, selectedBook: $selectedBook, activeCoverID: $activeCoverID, allBooks: allBooks, allRecords: allRecords)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            FluidEmptyReadingHero(allBooks: allBooks, allRecords: allRecords)
                            .frame(maxWidth: .infinity)
                        }
                        FluidFocusTimer(allRecords: allRecords, currentBook: activeReadingBook).frame(width: 450)
                    }
                    .frame(height: 280)
                        
                    // 🌟 Row 2: 视觉数据双轨
                    VStack(spacing: 32) {
                        FluidMomentumChart(allRecords: allRecords)
                        FluidHeatmapRibbon(allRecords: allRecords)
                    }
                    .padding(.top, 10).padding(.bottom, 20)
                        
                    // 🌟 Row 3: 思想碰撞与未来队列
                    HStack(spacing: 24) {
                        FluidResonanceWaveChart(allExcerpts: allExcerpts).frame(maxWidth: .infinity, maxHeight: .infinity)
                        FluidQueueBookshelfChart(wantToReadBooks: wantToReadBooks).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: 300)
                                                    
                    // 🌟 Row 4: 底部基石
                    FluidKnowledgeSpectrumCard(readBooks: readBooks).frame(maxWidth: .infinity).frame(height: 140)
                }
                .padding(.horizontal, 60).padding(.bottom, 80)
            }
            .zIndex(1)
                
            // 顶层悬浮 Header
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(greeting).font(.system(size: 32, weight: .heavy, design: .rounded)).foregroundColor(.primary).padding(.bottom, 8)
                        Text("Read as if you've never read...").font(.system(size: 15, weight: .medium)).foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 32) {
                        MicroMetricRing(title: "本周打卡", current: weekCount, target: Int(weekTarget), color: .pink, icon: "flame.fill")
                        MicroMetricRing(title: "本月历程", current: monthlyDays, target: Int(monthTarget), color: .mint, icon: "calendar")
                        MicroMetricRing(title: "年度阅卷", current: yearlyCount, target: Int(yearTarget), color: .cyan, icon: "book.pages.fill")
                    }
                }
                .padding(.horizontal, 40).padding(.top, 45).padding(.bottom, 20)
                Divider().background(Color.primary.opacity(0.05))
            }
            .frame(height: 130, alignment: .bottom)
            .background(Color.clear.background(.ultraThinMaterial).opacity(0.85))
            .ignoresSafeArea(edges: .top).zIndex(100)
        }
        .onAppear { calculateStats() }
        .onChange(of: allRecords) { _, _ in calculateStats() }
        .onChange(of: allBooks) { _, _ in calculateStats() }
    }
    
    private func calculateStats() {
        let cal = Calendar.current; let today = Date()
        yearlyCount = allBooks.filter { $0.status == .finished && cal.component(.year, from: $0.endTime ?? Date.distantFuture) == cal.component(.year, from: today) }.count
        monthlyDays = Set(allRecords.filter { cal.isDate($0.date ?? Date.distantPast, equalTo: today, toGranularity: .month) }.map { cal.component(.day, from: $0.date!) }).count
        weekCount = (cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)).map { start in (0..<7).filter { i in cal.date(byAdding: .day, value: i, to: start).map { d in allRecords.contains(where: { cal.isDate($0.date ?? Date.distantPast, inSameDayAs: d) }) } ?? false }.count } ?? 0)
    }
}

/// ✨ 微缩版指标圆环组件 (仅供 Header 使用)
private struct MicroMetricRing: View {
    let title: String; let current: Int; let target: Int; let color: Color; let icon: String
    var body: some View {
        let progress = min(Double(current) / Double(max(target, 1)), 1.0)
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 5)
                Circle().trim(from: 0, to: CGFloat(progress)).stroke(color.gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90)).animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundColor(color)
            }.frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(current)").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                    Text("/\(target)").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.secondary.opacity(0.6))
                }
                Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            }
        }
    }
}
#endif
