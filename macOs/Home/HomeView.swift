#if os(macOS)
import SwiftData
import SwiftUI

// MARK: - 🌊 流动书房主页 (UI 画布层)

struct FluidLibraryHomeView: View {
    // MARK: - 📥 全局配置
    
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - 🎮 视图路由状态
    
    @Binding var selectedBook: Book?
    
    // MARK: - 📊 异步图表驱动状态 (DTO)
    
    @State private var yearlyCount: Int = 0
    @State private var monthlyDays: Int = 0
    @State private var weekCount: Int = 0
    
    @State private var momentumPoints: [MomentumDataPoint] = []
    @State private var momentumTotal: Int = 0
    
    @State private var heatmapColumns: [[HeatmapDataPoint]] = []
    @State private var heatmapActiveDays: Int = 0
    
    @State private var resonancePoints: [ResonanceDataPoint] = []
    
    @State private var queueBooksData: [QueueBookDataPoint] = []
    
    @State private var spectrumPoints: [SpectrumDataPoint] = []
        
    @State private var activeReadingBook: Book? = nil
    
    /// ✨ 核心机制：强制状态驱动首屏大盘入场锁
    @State private var isEntranceAnimated: Bool = false

    var body: some View {
        // 1. 主体滚动区 (已彻底移除外层 ZStack 与底层背景)
        ScrollView(.vertical, showsIndicators: false) {
            // 物理锁定布局中轴线
            ZStack {
                LazyVStack(spacing: 40) {
                    Spacer().frame(height: 120)
                        
                    // 🌟 Row 1: 核心操作区 (Hero Section)
                    HStack {
                        if let heroBook = activeReadingBook {
                            FluidReadingHero(book: heroBook)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.appFluidSpring) { self.selectedBook = heroBook }
                                }
                                .onHover { isHovered in
                                    if isHovered { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                }
                        } else {
                            FluidEmptyReadingHero()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        FluidAmbientClock()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .frame(height: 280)
                        
                    // 🌟 Row 2: 视觉数据双轨
                    VStack(spacing: 32) {
                        FluidMomentumChart(dataPoints: momentumPoints, totalMinutes: momentumTotal)
                        FluidHeatmapRibbon(columns: heatmapColumns, activeDays: heatmapActiveDays)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                        
                    // 🌟 Row 3: 思想碰撞与未来队列
                    HStack(spacing: 24) {
                        FluidResonanceWaveChart(excerpts: resonancePoints)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        FluidQueueBookshelfChart(displayBooks: queueBooksData)
                    }
                    .frame(height: 300)
                    // 🌟 Row 4: 底部基石
                    FluidKnowledgeSpectrumCard(dataPoints: spectrumPoints)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 80)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            // 底部大盘电梯升空动效
            .opacity(isEntranceAnimated ? 1.0 : 0.0)
            .offset(y: isEntranceAnimated ? 0 : 150)
            .scaleEffect(isEntranceAnimated ? 1.0 : 0.99, anchor: .center)
            .animation(.appFluidSpring, value: isEntranceAnimated)
        }
        // 2. ✨ 顶层悬浮 Header (转化为 overlay 附加，不再需要 ZStack 堆叠)
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    // 👈 左侧文字区：戏剧性向右滑入
                    VStack(alignment: .leading, spacing: 8) {
                        Text(greeting)
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.top, 8)
                        Text("Read as if you've never read...")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    // ✨ 核心增强 1：下沉距离拉大到 200 像素，创造猛烈的交汇轨迹
                    .opacity(isEntranceAnimated ? 1.0 : 0.0)
                    .offset(x: isEntranceAnimated ? 0 : -200)
                    
                    Spacer()
                    
                    // 👉 右侧数据区：戏剧性向左滑入
                    HStack(spacing: 32) {
                        MicroMetricRing(title: "本周打卡", current: weekCount, target: 7, color: .pink, icon: "flame.fill")
                        MicroMetricRing(title: "本月历程", current: monthlyDays, target: 30, color: .mint, icon: "calendar")
                        MicroMetricRing(title: "年度阅卷", current: yearlyCount, target: yearTarget, color: .cyan, icon: "book.pages.fill")
                    }
                    // ✨ 核心增强 2：下沉距离同样拉大到 200 像素，双向奔赴！
                    .opacity(isEntranceAnimated ? 1.0 : 0.0)
                    .offset(x: isEntranceAnimated ? 0 : 200)
                }
                .padding(.horizontal, 40)
                .padding(.top, 45)
                .padding(.bottom, 20)
                // ✨ 统一使用一个 Fluid Spring 控制内部左右交汇
                .animation(.appFluidSpring, value: isEntranceAnimated)
                
                Divider().background(Color.primary.opacity(0.05))
             }
            .frame(height: 130, alignment: .bottom)
            .background(Color.clear.background(.ultraThinMaterial).opacity(0.85))
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            isEntranceAnimated = false
            loadAllDashboardData(animate: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RecordDidUpdate"))) { _ in
            loadAllDashboardData(animate: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LibraryDidUpdate"))) { _ in
            loadAllDashboardData(animate: true)
        }
    }
}

// MARK: - ⚙️ 异步数据调度引擎 (Service Layer - 保持不变)

extension FluidLibraryHomeView {
    private func loadAllDashboardData(animate: Bool) {
        Task { @MainActor in
            calculateBaseStats()
            let newActiveBook = fetchActiveReadingBook()
            let momentum = fetchMomentumData()
            let heatmap = fetchHeatmapData()
            let newResonance = fetchResonanceData()
            let newQueue = fetchQueueBooksData()
            let newSpectrum = fetchSpectrumData()
            
            if animate && self.isEntranceAnimated {
                withAnimation(.appFluidSpring) {
                    self.activeReadingBook = newActiveBook
                    self.momentumPoints = momentum.points
                    self.momentumTotal = momentum.total
                    self.heatmapColumns = heatmap.columns
                    self.heatmapActiveDays = heatmap.activeDays
                    self.resonancePoints = newResonance
                    self.queueBooksData = newQueue
                    self.spectrumPoints = newSpectrum
                }
            } else {
                self.activeReadingBook = newActiveBook
                self.momentumPoints = momentum.points
                self.momentumTotal = momentum.total
                self.heatmapColumns = heatmap.columns
                self.heatmapActiveDays = heatmap.activeDays
                self.resonancePoints = newResonance
                self.queueBooksData = newQueue
                self.spectrumPoints = newSpectrum
            }
            
            if !self.isEntranceAnimated {
                try? await Task.sleep(nanoseconds: 60_000_000)
                withAnimation(.appFluidSpring) {
                    self.isEntranceAnimated = true
                }
            }
        }
    }
        
    @MainActor
    private func fetchMomentumData() -> (points: [MomentumDataPoint], total: Int) {
        let cal = Calendar.current; let today = cal.startOfDay(for: Date())
        let startDate = cal.date(byAdding: .day, value: -13, to: today)!
            
        let descriptor = FetchDescriptor<ReadingRecord>(predicate: #Predicate { $0.date >= startDate })
        let recentRecords = (try? modelContext.fetch(descriptor)) ?? []
            
        var buckets: [Date: Double] = [:]
        for i in 0..<14 {
            buckets[cal.date(byAdding: .day, value: -i, to: today)!] = 0.0
        }
            
        var totalMins = 0.0
        for record in recentRecords {
            let recordDate = cal.startOfDay(for: record.date)
            if buckets.keys.contains(recordDate) {
                let mins = record.readingDuration / 60.0
                buckets[recordDate]! += mins
                totalMins += mins
            }
        }
            
        var points: [MomentumDataPoint] = []
        for i in (0..<14).reversed() {
            let date = cal.date(byAdding: .day, value: -i, to: today)!
            points.append(MomentumDataPoint(date: date, minutes: buckets[date]!, isToday: i == 0))
        }
        return (points, Int(totalMins))
    }
        
    @MainActor
    private func fetchHeatmapData() -> (columns: [[HeatmapDataPoint]], activeDays: Int) {
        var cal = Calendar.current; cal.firstWeekday = 2
        let today = cal.startOfDay(for: Date())
                    
        let daysToSubtract = (cal.component(.weekday, from: today) + 5) % 7
        let currentWeekStart = cal.date(byAdding: .day, value: -daysToSubtract, to: today)!
        let startDate = cal.date(byAdding: .weekOfYear, value: -52, to: currentWeekStart)!
                    
        let descriptor = FetchDescriptor<ReadingRecord>(predicate: #Predicate { $0.date >= startDate })
        let recentRecords = (try? modelContext.fetch(descriptor)) ?? []
                    
        var durs: [Date: TimeInterval] = [:]; var activeDays = 0
        for r in recentRecords {
            durs[cal.startOfDay(for: r.date), default: 0] += r.readingDuration
        }
                    
        var cols = [[HeatmapDataPoint]]()
        for w in 0..<53 {
            var col = [HeatmapDataPoint]()
            for d in 0..<7 {
                let date = cal.date(byAdding: .day, value: w * 7 + d, to: startDate)!
                let dur = durs[date] ?? 0; let isFuture = date > today; var intensity = 0.0
                            
                if !isFuture && dur > 0 {
                    activeDays += 1
                    let mins = Int(dur / 60)
                    // ✨ 核心替换：抛弃臃肿的判断，直接呼叫全局引擎！
                    intensity = VisualEngines.ReadingHeatmap.intensity(for: mins)
                }
                            
                let dateString = date.formatted(.dateTime.month().day())
                let tooltip = isFuture ? "未到" : (dur == 0 ? "\(dateString): 未打卡" : "\(dateString): 专注 \(Int(dur / 60)) 分钟")
                col.append(HeatmapDataPoint(date: date, intensity: intensity, isFuture: isFuture, tooltip: tooltip))
            }
            cols.append(col)
        }
        return (cols, activeDays)
    }
    
    @MainActor
    private func calculateBaseStats() {
        let cal = Calendar.current; let today = Date()
            
        let startOfYear = cal.date(from: cal.dateComponents([.year], from: today))!
        let recordDesc = FetchDescriptor<ReadingRecord>(predicate: #Predicate { $0.date >= startOfYear })
        let currentYearRecords = (try? modelContext.fetch(recordDesc)) ?? []
            
        let bookDesc = FetchDescriptor<Book>()
        let allBooks = (try? modelContext.fetch(bookDesc)) ?? []
        let finishedBooks = allBooks.filter { $0.status == .finished }
            
        yearlyCount = finishedBooks.filter { cal.component(.year, from: $0.endTime ?? Date.distantFuture) == cal.component(.year, from: today) }.count
        monthlyDays = Set(currentYearRecords.filter { cal.isDate($0.date, equalTo: today, toGranularity: .month) }.map { cal.component(.day, from: $0.date) }).count
        weekCount = Set(currentYearRecords.filter { cal.isDate($0.date, equalTo: today, toGranularity: .weekOfYear) }.map { cal.component(.day, from: $0.date) }).count
    }
    
    @MainActor
    private func fetchResonanceData() -> [ResonanceDataPoint] {
        // ✨ 1. 声明要过滤的类型：只查摘录
        let targetType = AnnotationType.excerpt
            
        // ✨ 2. 改为查询统一的 BookAnnotation 实体，并加上精准的 Predicate 过滤
        var descriptor = FetchDescriptor<BookAnnotation>(
            predicate: #Predicate<BookAnnotation> { $0.type == targetType },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        // 抓取最新的 100 条用于跑马灯洗牌
        descriptor.fetchLimit = 100
            
        let recentExcerpts = (try? modelContext.fetch(descriptor)) ?? []
        if recentExcerpts.isEmpty { return [] }
            
        return recentExcerpts.map {
            ResonanceDataPoint(content: $0.content, source: $0.book?.title ?? "札记")
        }.shuffled() // 每次打开主页，这 100 条摘录都会随机洗牌
    }
    
    @MainActor
    private func fetchQueueBooksData() -> [QueueBookDataPoint] {
        let descriptor = FetchDescriptor<Book>()
        let allBooks = (try? modelContext.fetch(descriptor)) ?? []
            
        let pendingBooks = Array(allBooks.filter { $0.status == .wantToRead }.prefix(4))
            
        return pendingBooks.map {
            QueueBookDataPoint(id: $0.id, title: $0.title, author: $0.author, coverData: $0.coverData)
        }
    }
    
    @MainActor
    private func fetchActiveReadingBook() -> Book? {
        let descriptor = FetchDescriptor<Book>()
        let allBooks = (try? modelContext.fetch(descriptor)) ?? []
            
        let readingBooks = allBooks.filter { $0.status == .reading }
            
        return readingBooks.max { b1, b2 in
            let date1 = b1.readingRecords?.compactMap(\.date).max() ?? b1.startTime ?? .distantPast
            let date2 = b2.readingRecords?.compactMap(\.date).max() ?? b2.startTime ?? .distantPast
            return date1 < date2
        }
    }
        
    @MainActor
    private func fetchSpectrumData() -> [SpectrumDataPoint] {
        let descriptor = FetchDescriptor<Book>()
        let allBooks = (try? modelContext.fetch(descriptor)) ?? []
            
        let finishedBooks = allBooks.filter { $0.status == .finished }
            
        var counts: [String: Double] = [:]
        for b in finishedBooks {
            for t in b.tags {
                counts[t, default: 0] += 1
            }
        }
            
        let top5 = counts.sorted { $0.value > $1.value }.prefix(5)
        let top5Total = top5.reduce(0.0) { $0 + $1.value }
        guard top5Total > 0 else { return [] }
            
        let colors: [Color] = [.purple, .indigo, .teal, .orange, .blue]
        return top5.enumerated().map { index, element in
            SpectrumDataPoint(tagName: element.key, percentage: (element.value / top5Total) * 100.0, color: colors[index % colors.count])
        }
    }
}

// MARK: - 🗃️ 静态配置与小部件数据 (保持不变)

extension FluidLibraryHomeView {
    private var yearTarget: Int {
        configs.first?.yearlyBookGoal ?? 50
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 9 { return "晨光正好，宜卷开新章。" }
        else if hour < 14 { return "午后静谧，在文字中漫步。" }
        else if hour < 19 { return "夕阳西下，且将思想沉淀。" }
        else { return "夜色温润，伴书香入眠。" }
    }
}

// MARK: - ✨ 附加子组件 (保持不变)

private struct MicroMetricRing: View {
    let title: String; let current: Int; let target: Int; let color: Color; let icon: String
    var body: some View {
        let progress = min(Double(current) / Double(max(target, 1)), 1.0)
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(color.gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.appFluidSpring, value: progress)
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

#Preview("流动书房主页") {
    struct PreviewWrapper: View {
        @State private var selectedBook: Book? = nil
        var body: some View {
            FluidLibraryHomeView(selectedBook: $selectedBook)
                .frame(width: 1100, height: 800)
        }
    }
    return PreviewWrapper().modelContainer(PreviewData.shared)
}
#endif
