#if os(macOS)
import SwiftData
import SwiftUI

// MARK: - 🌊 流动书房主页 (UI 画布层)

struct HomeView: View {
    // MARK: - 📥 全局配置
    
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - 🎮 视图路由状态
    
    @Binding var selectedBook: Book? // 仅保留详情页绑定
    
    // MARK: - 📊 异步图表驱动状态
    
    @State private var yearlyCount: Int = 0
    @State private var monthlyDays: Int = 0
    @State private var weekCount: Int = 0
    
    @State private var momentumPoints: [MomentumDataPoint] = []
    @State private var momentumTotal: Int = 0
    
    @State private var heatmapColumns: [[HeatmapDataPoint]] = []
    @State private var heatmapActiveDays: Int = 0
    
    @State private var resonancePoints: [ResonanceDataPoint] = []
    
    @State private var queueBooksData: [Book] = []
    
    @State private var spectrumPoints: [SpectrumDataPoint] = []
        
    @State private var activeReadingBook: Book? = nil
    
    @State private var isEntranceAnimated: Bool = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ZStack {
                LazyVStack(spacing: 40) {
                    Spacer().frame(height: 120)
                        
                    // 🌟 Row 1: 核心操作区 (Hero Section) - UI 布局严格保留你的原样
                    HStack {
                        if let heroBook = activeReadingBook {
                            ReadingHero(book: heroBook) {
                                // 点击右上角按钮：触发详情页
                                withAnimation(.appFluidSpring) { self.selectedBook = heroBook }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.appFluidSpring) { self.selectedBook = heroBook }
                            }
                            .onHover { isHovered in
                                if isHovered { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                            }
                        } else {
                            EmptyReadingHero()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        AmbientClock()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .frame(height: 280)
                        
                    // 🌟 Row 2: 视觉数据双轨
                    VStack(spacing: 32) {
                        MomentumChart(dataPoints: momentumPoints, totalMinutes: momentumTotal)
                        HeatmapRibbon(columns: heatmapColumns, activeDays: heatmapActiveDays)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                        
                    // 🌟 Row 3: 思想碰撞与未来队列
                    HStack(spacing: 24) {
                        ResonanceWave(excerpts: resonancePoints)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // ✨ 点击闭包：处理想读变在读，并发送阅读通知
                        QueueBookshelf(displayBooks: queueBooksData) { tappedBook in
                            startReadingFromQueue(book: tappedBook)
                        }
                    }
                    .frame(height: 300)

                    // 🌟 Row 4: 底部基石
                    KnowledgeSpectrum(dataPoints: spectrumPoints)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 80)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .opacity(isEntranceAnimated ? 1.0 : 0.0)
            .offset(y: isEntranceAnimated ? 0 : 150)
            .scaleEffect(isEntranceAnimated ? 1.0 : 0.99, anchor: .center)
            .animation(.appFluidSpring, value: isEntranceAnimated)
        }
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(greeting)
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.top, 8)
                        Text("Read as if you've never read...")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .opacity(isEntranceAnimated ? 1.0 : 0.0)
                    .offset(x: isEntranceAnimated ? 0 : -200)
                    
                    Spacer()
                    
                    HStack(spacing: 32) {
                        MicroMetricRing(title: "本周打卡", current: weekCount, target: 7, color: .pink, icon: "flame.fill")
                        MicroMetricRing(title: "本月历程", current: monthlyDays, target: 30, color: .mint, icon: "calendar")
                        MicroMetricRing(title: "年度阅卷", current: yearlyCount, target: yearTarget, color: .cyan, icon: "book.pages.fill")
                    }
                    .opacity(isEntranceAnimated ? 1.0 : 0.0)
                    .offset(x: isEntranceAnimated ? 0 : 200)
                }
                .padding(.horizontal, 40)
                .padding(.top, 45)
                .padding(.bottom, 20)
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
        .onReceive(NotificationCenter.default.publisher(for: .libraryDidUpdate)) { _ in
            loadAllDashboardData(animate: true)
        }
    }
}

// MARK: - ⚙️ 异步数据调度引擎

extension HomeView {
    
    @MainActor
    private func startReadingFromQueue(book: Book) {
        if book.status == .planned {
            book.status = .reading
            book.startDate = Date()
            // ✨ 核心修复：一旦开始阅读，必须立即更新最后阅读时间，强制让它霸占焦点位！
            book.lastReadAt = Date()
            try? modelContext.save()
            // 刷新主页在读卡片
            NotificationCenter.default.post(name: .libraryDidUpdate, object: nil)
        }
        withAnimation(.appFluidSpring) { selectedBook = book }
    }
    
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
        let descriptor = FetchDescriptor<ReadingSession>(predicate: #Predicate { $0.date >= startDate })
        let recentRecords = (try? modelContext.fetch(descriptor)) ?? []
        var buckets: [Date: Double] = [:]
        for i in 0..<14 { buckets[cal.date(byAdding: .day, value: -i, to: today)!] = 0.0 }
        var totalMins = 0.0
        for record in recentRecords {
            let recordDate = cal.startOfDay(for: record.date)
            if buckets.keys.contains(recordDate) {
                let mins = record.duration / 60.0
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
        let descriptor = FetchDescriptor<ReadingSession>(predicate: #Predicate { $0.date >= startDate })
        let recentRecords = (try? modelContext.fetch(descriptor)) ?? []
        var durs: [Date: TimeInterval] = [:]; var activeDays = 0
        for r in recentRecords { durs[cal.startOfDay(for: r.date), default: 0] += r.duration }
        var cols = [[HeatmapDataPoint]]()
        for w in 0..<53 {
            var col = [HeatmapDataPoint]()
            for d in 0..<7 {
                let date = cal.date(byAdding: .day, value: w * 7 + d, to: startDate)!
                let dur = durs[date] ?? 0; let isFuture = date > today; var intensity = 0.0
                if !isFuture && dur > 0 {
                    activeDays += 1
                    intensity = VisualEngines.ReadingHeatmap.intensity(for: Int(dur / 60))
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
        let recordDesc = FetchDescriptor<ReadingSession>(predicate: #Predicate { $0.date >= startOfYear })
        let currentYearRecords = (try? modelContext.fetch(recordDesc)) ?? []
        let bookDesc = FetchDescriptor<Book>(); let allBooks = (try? modelContext.fetch(bookDesc)) ?? []
        let finishedBooks = allBooks.filter { $0.status == .finished }
        yearlyCount = finishedBooks.filter { cal.component(.year, from: $0.finishDate ?? Date.distantFuture) == cal.component(.year, from: today) }.count
        monthlyDays = Set(currentYearRecords.filter { cal.isDate($0.date, equalTo: today, toGranularity: .month) }.map { cal.component(.day, from: $0.date) }).count
        weekCount = Set(currentYearRecords.filter { cal.isDate($0.date, equalTo: today, toGranularity: .weekOfYear) }.map { cal.component(.day, from: $0.date) }).count
    }
    
    @MainActor
        private func fetchResonanceData() -> [ResonanceDataPoint] {
            var descriptor = FetchDescriptor<BookAnnotation>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            // 抓取最新的 300 条用于过滤
            descriptor.fetchLimit = 300
            let allRecentAnnotations = (try? modelContext.fetch(descriptor)) ?? []
            
            // 使用原生的 Swift filter 寻找摘录
            let recentExcerpts = allRecentAnnotations.filter { $0.type == .excerpt }
            if recentExcerpts.isEmpty { return [] }
            
            return Array(recentExcerpts.prefix(100)).map {
                ResonanceDataPoint(content: $0.content, source: $0.book?.title ?? "札记")
            }.shuffled()
        }
    
    @MainActor
    private func fetchQueueBooksData() -> [Book] {
        let descriptor = FetchDescriptor<Book>()
        let allBooks = (try? modelContext.fetch(descriptor)) ?? []
        return Array(allBooks.filter { $0.status == .planned }.prefix(4))
    }
    
    @MainActor
    private func fetchActiveReadingBook() -> Book? {
        let descriptor = FetchDescriptor<Book>()
        let allBooks = (try? modelContext.fetch(descriptor)) ?? []
        let readingBooks = allBooks.filter { $0.status == .reading }
        
        // ✨ 核心修复：严格依赖最后阅读时间来决定首页的唯一焦点
        return readingBooks.max(by: {
            let date1 = $0.lastReadAt ?? $0.startDate ?? $0.createdAt
            let date2 = $1.lastReadAt ?? $1.startDate ?? $1.createdAt
            // 如果 date1 小于 date2，说明 date2 更新，由于是 max(by:)，会挑出最新的那个
            return date1 < date2
        })
    }
        
    @MainActor
    private func fetchSpectrumData() -> [SpectrumDataPoint] {
        let descriptor = FetchDescriptor<Book>()
        let allBooks = (try? modelContext.fetch(descriptor)) ?? []
        let finishedBooks = allBooks.filter { $0.status == .finished }
        var counts: [String: Double] = [:]
        
        // ✨ 修复：因为 tags 已经是非可选的 Array，干掉了原来的 ?? [] 防御
        for b in finishedBooks {
            for t in b.tags { counts[t, default: 0] += 1 }
        }
        
        let top5 = counts.sorted { $0.value > $1.value }.prefix(5)
        let top5Total = top5.reduce(0.0) { $0 + $1.value }
        guard top5Total > 0 else { return [] }
        let colors: [Color] = [.purple, .indigo, .teal, .orange, .blue]
        return top5.enumerated().map { index, element in SpectrumDataPoint(tagName: element.key, percentage: (element.value / top5Total) * 100.0, color: colors[index % colors.count]) }
    }
}

extension HomeView {
    private var yearTarget: Int { configs.first?.yearlyBooksGoal ?? 50 }
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 9 { return "晨光正好，宜卷开新章。" }
        else if hour < 14 { return "午后静谧，在文字中漫步。" }
        else if hour < 19 { return "夕阳西下，且将思想沉淀。" }
        else { return "夜色温润，伴书香入眠。" }
    }
}

private struct MicroMetricRing: View {
    let title: String; let current: Int; let target: Int; let color: Color; let icon: String
    var body: some View {
        let progress = min(Double(current) / Double(max(target, 1)), 1.0)
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 5)
                Circle().trim(from: 0, to: CGFloat(progress)).stroke(color.gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90)).animation(.appFluidSpring, value: progress)
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
