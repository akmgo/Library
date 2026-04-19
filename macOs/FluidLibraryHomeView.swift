#if os(macOS)
internal import Combine
import Charts
import SwiftData
import SwiftUI

// MARK: - 🌊 流动书房主页 (Fluid Library)

struct FluidLibraryHomeView: View {
    @Query var allBooks: [Book]
    @Query var allRecords: [ReadingRecord]
    @Query var allExcerpts: [Excerpt]
    
    
    
    let namespace: Namespace.ID
    @Binding var selectedBook: Book?
    @Binding var activeCoverID: String
    
    // 📊 统计数据状态
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]

    // ✨ 动态提取年度目标
        var yearTarget: Double {
            Double(configs.first?.yearlyBookGoal ?? 50)
        }

    let monthTarget = 30.0
    let weekTarget = 7.0
    
    @State private var yearlyCount: Int = 0
    @State private var monthlyDays: Int = 0
    @State private var weekCount: Int = 0
    
    // ✨ 智能计算：获取最近活动的在读书籍
        var activeReadingBook: Book? {
            allBooks
                .filter { $0.status == .reading }
                .max { b1, b2 in
                    // 比较两本书最新的打卡记录时间，如果没有打卡记录，就比较开始阅读的时间
                    let date1 = b1.readingRecords?.compactMap(\.date).max() ?? b1.startTime ?? .distantPast
                    let date2 = b2.readingRecords?.compactMap(\.date).max() ?? b2.startTime ?? .distantPast
                    return date1 < date2
                }
        }

    var readBooks: [Book] {
        allBooks.filter { $0.status == .finished }
    }

    var wantToReadBooks: [Book] {
        allBooks.filter { $0.isWantToRead }
    }
    
    /// 动态问候语 (带有一丝文学气息)
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 9 { return "晨光正好，宜卷开新章。" }
        else if hour < 14 { return "午后静谧，在文字中漫步。" }
        else if hour < 19 { return "夕阳西下，且将思想沉淀。" }
        else { return "夜色温润，伴书香入眠。" }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // ================= 1. 氛围感环境背景 =================
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
                
            Circle()
                .fill(Color.indigo.opacity(0.08))
                .blur(radius: 120)
                .frame(width: 800, height: 800)
                .offset(x: -200, y: -300)

            // ================= 2. 透明滚动区 (✨ 卡顿优化：使用 LazyVStack) =================
            ScrollView(.vertical, showsIndicators: false) {
                // ⚠️ 关键性能优化：LazyVStack 会在视图进入屏幕时才渲染，极大缓解复杂图表和阴影导致的滑动卡顿
                LazyVStack(spacing: 40) {
                    // 预留顶部毛玻璃的高度空间
                    Spacer().frame(height: 120)
                        
                    // 🌟 核心操作区 (Hero Section)
                    HStack(spacing: 60) {
                        if let heroBook = activeReadingBook {
                            FluidReadingHero(
                                book: heroBook,
                                progress: Double(heroBook.progress),
                                namespace: namespace,
                                selectedBook: $selectedBook,
                                activeCoverID: $activeCoverID,
                                allBooks: allBooks,
                                allRecords: allRecords
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            FluidEmptyReadingHero(
                                allBooks: allBooks,
                                allRecords: allRecords
                            )
                            .frame(maxWidth: .infinity)
                        }
                            
                        FluidFocusTimer(allRecords: allRecords, readingBooks: allBooks.filter { $0.status == .reading })
                            .frame(width: 450)
                    }
                    .frame(height: 280)
                        
                    // 🌟 视觉数据双轨：无界热力带 + 近期动能图
                    VStack(spacing: 32) { // 将它俩绑在一起，中间留出一定呼吸间距
                        FluidMomentumChart(allRecords: allRecords)
                                            
                        FluidHeatmapRibbon(allRecords: allRecords)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                        
                    // 🌟 Row 3: 思想碰撞与未来队列
                    HStack(spacing: 24) {
                        FluidResonanceWaveChart(allExcerpts: allExcerpts)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        FluidQueueBookshelfChart(wantToReadBooks: wantToReadBooks)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: 300)
                                            
                    // 🌟 Row 4: 底部基石
                    FluidKnowledgeSpectrumCard(readBooks: readBooks)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 80)
            }
            .zIndex(1)
                
            // ================= 3. 顶层：固定悬浮高定玻璃 Header =================
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    // 左侧：问候语
                    VStack(alignment: .leading, spacing: 8) {
                        Text(greeting)
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.bottom, 8)
                                    
                        Text("Read as if you've never read...")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                                
                    Spacer()
                                
                    // ✨ 右侧：原本在卡片里的能量圆环被提拔到了这里！
                    // 请确保 weekCount, monthCount 等变量在你的 View 中是可以访问的
                    HStack(spacing: 32) {
                        MicroMetricRing(title: "本周打卡", current: weekCount, target: Int(weekTarget), color: .pink, icon: "flame.fill")
                        MicroMetricRing(title: "本月历程", current: monthlyDays, target: Int(monthTarget), color: .mint, icon: "calendar")
                        MicroMetricRing(title: "年度阅卷", current: yearlyCount, target: Int(yearTarget), color: .cyan, icon: "book.pages.fill")
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 45) // 与画廊、灵感墙等完全对齐
                .padding(.bottom, 20)
                            
                Divider().background(Color.primary.opacity(0.05))
            }
            .frame(height: 130, alignment: .bottom) // 之前计算的锁定高度
            .background(
                Color.clear
                    .background(.ultraThinMaterial)
                    .opacity(0.85)
            )
            .ignoresSafeArea(edges: .top)
            .zIndex(100) // 确保永远在最上层
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

// MARK: - 🎨 专属流动组件：无边框在读焦点 + 融合指标 (FluidReadingHero)

struct FluidReadingHero: View {
    let book: Book
    let progress: Double
    let namespace: Namespace.ID
    @Binding var selectedBook: Book?
    @Binding var activeCoverID: String
    
    // 💡 引入全量数据来计算融合指标
    let allBooks: [Book]
    let allRecords: [ReadingRecord]
    
    @State private var isHovered = false
    
    var body: some View {
        let safeTitle = book.title ?? "未知"
        let safeAuthor = book.author ?? "未知作者"
        let normalizedProgress = min(max(progress / 100.0, 0), 1.0)
        
        HStack(alignment: .center, spacing: 40) {
            // ================= 1. 左侧：巨型实体书封面 =================
            ZStack {
                if selectedBook?.id != book.id {
                    LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                        .frame(width: 170, height: 245)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .matchedGeometryEffect(id: "hero-\(book.id ?? UUID().uuidString)", in: namespace)
                        .shadow(color: Color.black.opacity(isHovered ? 0.3 : 0.15), radius: isHovered ? 20 : 12, y: isHovered ? 12 : 8)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                } else {
                    LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                        .frame(width: 170, height: 245).opacity(0.001)
                }
            }
            .onHover { h in withAnimation(.spring()) { isHovered = h }; if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            .onTapGesture { activeCoverID = "hero-\(book.id ?? UUID().uuidString)"; withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { selectedBook = book } }
            
            // ================= 2. 右侧：排版与融合数据 =================
            VStack(alignment: .leading, spacing: 0) {
                // --- 顶部：书籍元数据 ---
                Text("CURRENTLY READING")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.blue)
                    .tracking(2)
                    .padding(.bottom, 6)
                
                Text(safeTitle)
                    .font(.system(size: 36, weight: .heavy, design: .serif))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                Text(safeAuthor)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.top, 4)
                
                Spacer()
                
                // --- 底部：专属阅读进度 ---
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .lastTextBaseline) {
                        Text("\(Int(progress))%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    ProgressView(value: normalizedProgress)
                        .progressViewStyle(.linear)
                        .tint(.primary)
                }
            }
            .frame(height: 220)
        }
    }
}

// MARK: - 🎨 专属流动组件：在读焦点空状态 (FluidEmptyReadingHero)

struct FluidEmptyReadingHero: View {
    // 💡 依然需要传入全量数据，因为我们要展示用户的宏观打卡指标！
    let allBooks: [Book]
    let allRecords: [ReadingRecord]
    
    var body: some View {
        HStack(alignment: .center, spacing: 40) {
            // ================= 1. 左侧：精美的幽灵占位封面 =================
            ZStack {
                // 虚线框，暗示这是一个空位
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                    .frame(width: 170, height: 245)
                    .background(Color.secondary.opacity(0.02)) // 极其微弱的底色填充
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                VStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("暂无在读")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            // 依然添加悬浮交互，虽然是空的，但保持组件响应性一致
            .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            
            // ================= 2. 右侧：半透明排版与常驻数据 =================
            VStack(alignment: .leading, spacing: 0) {
                // --- 顶部：占位文案 ---
                Text("CURRENTLY READING")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.3)) // 颜色变淡
                    .tracking(2)
                    .padding(.bottom, 6)
                
                Text("虚位以待")
                    .font(.system(size: 36, weight: .heavy, design: .serif))
                    .foregroundColor(.primary.opacity(0.4)) // 降低透明度，营造“空”的感觉
                    .lineLimit(2)
                
                Text("去书库中挑选一本开启新旅程吧")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.5))
                    .lineLimit(1)
                    .padding(.top, 4)
                
                Spacer()
                
                // --- 底部：归零的进度条 ---
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .lastTextBaseline) {
                        Text("0%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.3))
                        Spacer()
                    }
                    ProgressView(value: 0)
                        .progressViewStyle(.linear)
                        .tint(.secondary.opacity(0.2)) // 进度条变成灰色
                }
            }
            .frame(height: 220)
        }
    }
}

/// ✨ 微缩版指标圆环 (重构布局：环内图标，右侧数据/标题)
private struct MicroMetricRing: View {
    let title: String
    let current: Int
    let target: Int
    let color: Color
    let icon: String // 👈 新增 icon 属性

    var body: some View {
        let progress = min(Double(current) / Double(max(target, 1)), 1.0)

        HStack(spacing: 12) {
            // 左侧：精致的发光小圆环 + 中心图标
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(color.gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                
                // ✨ 环内恢复经典 Icon
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }
            .frame(width: 38, height: 38)
            
            // 右侧：数据组合
            VStack(alignment: .leading, spacing: 2) {
                // 上方数据：比如 2/7
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(current)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("/\(target)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                
                // 下方标题：比如 本周打卡
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 🎨 专属流动组件：年度无界热力带 (FluidHeatmapRibbon)

struct FluidHeatmapRibbon: View {
    let allRecords: [ReadingRecord]
    @State private var heatmapColumns: [[(Date, Double, Bool, String)]] = []
    
    /// 新增：年度活跃天数统计，作为右侧的点缀
    @State private var activeDaysThisYear: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ================= 1. 顶部标题栏 (左右对齐) =================
            HStack(alignment: .bottom) {
                Text("365 DAYS JOURNEY")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.secondary)
                    .tracking(2)
                
                Spacer()
                
                // 右侧微型统计：年度打卡天数
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(activeDaysThisYear)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Days")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            // ================= 2. 全年热力矩阵 (自适应等宽) =================
            // 控制周与周的水平间距
            HStack(spacing: 4) {
                ForEach(0..<heatmapColumns.count, id: \.self) { c in
                    // 控制一星期内每天的垂直间距
                    VStack(spacing: 4) {
                        ForEach(0..<heatmapColumns[c].count, id: \.self) { r in
                            let cell = heatmapColumns[c][r]
                            
                            // ✨ 神奇的弹性圆点
                            Circle()
                                .fill(cell.2 ? Color.clear : (cell.1 > 0 ? Color.indigo.opacity(cell.1) : Color.secondary.opacity(0.12)))
                                // 强制保持正圆
                                .aspectRatio(1, contentMode: .fit)
                                // ✨ 允许横向无限弹性拉伸，系统会自动将其平分，保证总宽度与上方模块 100% 对齐
                                .frame(maxWidth: .infinity)
                                .help(cell.3)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { process() }
        .onChange(of: allRecords) { _, _ in process() }
    }
    
    private func process() {
        var cal = Calendar.current
        cal.firstWeekday = 2 // 设定周一为每周第一天
        let today = cal.startOfDay(for: Date())
        
        var durs: [Date: TimeInterval] = [:]
        var activeDays = 0
        
        for r in allRecords {
            durs[cal.startOfDay(for: r.date ?? Date.distantPast), default: 0] += r.readingDuration
        }
        
        // 锁定当前周的周一
        let daysToSubtract = (cal.component(.weekday, from: today) + 5) % 7
        let currentWeekStart = cal.date(byAdding: .day, value: -daysToSubtract, to: today)!
        
        // ✨ 往前推 52 周，加上当前周，共 53 列（恰好覆盖完整的 365 天跨度）
        let totalWeeks = 53
        let start = cal.date(byAdding: .weekOfYear, value: -(totalWeeks - 1), to: currentWeekStart)!
        
        var cols = [[(Date, Double, Bool, String)]]()
        for w in 0..<totalWeeks {
            var col = [(Date, Double, Bool, String)]()
            for d in 0..<7 {
                let date = cal.date(byAdding: .day, value: w * 7 + d, to: start)!
                let dur = durs[date] ?? 0
                let fut = date > today
                var int = 0.0
                
                if !fut, dur > 0 {
                    // 将时间转换为热力图透明度：越久越深
                    int = min((dur / 3600.0) * 0.7 + 0.3, 1.0)
                    activeDays += 1
                }
                
                col.append((date, int, fut, fut ? "未到" : (dur == 0 ? "未打卡" : "专注 \(Int(dur / 60)) 分钟")))
            }
            cols.append(col)
        }
        
        // 更新状态驱动 UI
        heatmapColumns = cols
        activeDaysThisYear = activeDays
    }
}

// MARK: - ⏱️ 极简翻页时钟 (高度收紧，质感统一版)

struct FluidFocusTimer: View {
    let allRecords: [ReadingRecord]
    let readingBooks: [Book]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    
    @State private var isRunning = false
    @State private var unrecordedSeconds: TimeInterval = 0
    @State private var isColonVisible = true
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let cycleTime: TimeInterval = 20 * 60
    
    var todayRecord: ReadingRecord? {
        allRecords.first(where: { Calendar.current.isDateInToday($0.date ?? Date.distantPast) })
    }

    var totalActiveSeconds: TimeInterval {
        (todayRecord?.readingDuration ?? 0) + unrecordedSeconds
    }

    var remainingSeconds: TimeInterval {
        cycleTime - totalActiveSeconds.truncatingRemainder(dividingBy: cycleTime)
    }

    var completedCycles: Int {
        Int(totalActiveSeconds / cycleTime) % 5
    }
    
    var minutesString: String {
        String(format: "%02d", Int(remainingSeconds) / 60)
    }

    var secondsString: String {
        String(format: "%02d", Int(remainingSeconds) % 60)
    }
    
    var body: some View {
        let accentColor = Color.orange
        
        VStack(spacing: 24) { // 缩减大方块与底部胶囊的间距
            
            // ================= 1. 核心大时钟区 =================
            HStack(spacing: 16) {
                GiantTimeBlock(value: minutesString, label: "MINUTES")
                
                // 呼吸冒号
                Text(":")
                    .font(.system(size: 76, weight: .medium, design: .rounded))
                    .foregroundColor(isRunning ? accentColor : .secondary.opacity(0.4))
                    .opacity(isColonVisible ? 1.0 : 0.2)
                    .offset(y: -12) // 微调视觉居中
                
                GiantTimeBlock(value: secondsString, label: "SECONDS")
            }
            .shadow(color: Color.black.opacity(isRunning ? 0.12 : 0.04), radius: 20, y: 10)
            
            // ================= 2. 底部控制台 (统一质感胶囊) =================
            HStack(spacing: 24) {
                Button(action: toggleTimer) {
                    ZStack {
                        Circle()
                            .fill(isRunning ? accentColor.opacity(0.15) : Color.primary.opacity(0.06))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(isRunning ? accentColor : .primary.opacity(0.7))
                            .offset(x: isRunning ? 0 : 2)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                
                HStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { index in
                        Circle()
                            .fill(index < completedCycles ? accentColor.gradient : Color.secondary.opacity(0.15).gradient)
                            .frame(width: 10, height: 10)
                            .shadow(color: index < completedCycles ? accentColor.opacity(0.5) : .clear, radius: 4)
                    }
                }
                .padding(.trailing, 16)
            }
            .padding(8)
            // ✨ 修复：不再使用毛玻璃，使用与上方数字块完全一致的纯净底色逻辑
            .background(
                Capsule()
                    .fill(colorScheme == .light ? Color.white : Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        Capsule().stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .shadow(color: Color.black.opacity(colorScheme == .light ? 0.08 : 0.2), radius: 12, y: 6)
        }
        // ✨ 将总高度严格约束，在视觉上与左侧 245pt 的封面完美水平居中对齐
        .frame(height: 245, alignment: .center)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                if isRunning {
                    flushTimeToDatabase()
                    isRunning = false
                }
            }
        }
        .onReceive(timer) { _ in
            guard isRunning else { return }
            unrecordedSeconds += 1
            withAnimation(.easeInOut(duration: 0.5)) { isColonVisible.toggle() }
            if remainingSeconds == cycleTime { flushTimeToDatabase() }
        }
    }
    
    private func toggleTimer() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isRunning.toggle()
            isColonVisible = true
        }
        if !isRunning { flushTimeToDatabase() }
    }
    
    private func flushTimeToDatabase() {
        guard unrecordedSeconds > 0 else { return }
        if let record = todayRecord {
            record.readingDuration += unrecordedSeconds
            if record.book == nil { record.book = readingBooks.first }
        } else {
            let newRecord = ReadingRecord(date: Date(), readingDuration: unrecordedSeconds, book: readingBooks.first)
            modelContext.insert(newRecord)
        }
        unrecordedSeconds = 0; try? modelContext.save()
    }
}

// MARK: - 🧩 辅助组件：巨型日历数字块 (紧凑压迫感)

private struct GiantTimeBlock: View {
    let value: String
    let label: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 8) { // 缩减数字和标签的距离
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colorScheme == .light ? Color.white : Color(nsColor: .controlBackgroundColor))
                
                Rectangle()
                    .fill(Color.primary.opacity(colorScheme == .light ? 0.04 : 0.1))
                    .frame(height: 2)
                
                // ✨ 88pt 大字体，塞进 120pt 高的方块里，形成“顶天立地”的饱满视觉
                Text(value)
                    .font(.system(size: 88, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary.opacity(0.85))
            }
            // ✨ 高度从 160 大幅削减到 120，去除多余留白
            .frame(width: 120, height: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(colorScheme == .light ? 0.08 : 0.3), radius: 16, y: 8)
            
            Text(label)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.secondary.opacity(0.5))
                .tracking(3)
        }
    }
}

// MARK: - 🌊 思想共鸣 (纯净无界版 - 锁定字号)

struct FluidResonanceWaveChart: View {
    let allExcerpts: [Excerpt]
    @State private var curIdx: Int = 0
    let timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()
    
    var excerpt: Excerpt {
        if allExcerpts.isEmpty {
            return .init(content: "思想的留白，去阅读中遇见自己。")
        }
        // ✨ 补丁：如果当前索引因为数据删除而越界，安全回退到第一条
        if allExcerpts.indices.contains(curIdx) {
            return allExcerpts[curIdx]
        } else {
            return allExcerpts.first!
        }
    }
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Spacer(minLength: 0)
                
                Text(excerpt.content ?? "")
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .lineSpacing(10)
                    .foregroundColor(.primary.opacity(0.85))
                    .lineLimit(8)
                    // ✨ 删除了 minimumScaleFactor，现在无论长短，字体大小绝对一致
                    .id(curIdx)
                    .transition(.opacity.combined(with: .blurReplace))
                
                Spacer(minLength: 0)
                
                HStack {
                    Spacer()
                    Text("—— \(excerpt.book?.title ?? "札记")")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxHeight: .infinity)
        } label: {
            HStack {
                Text("思想共鸣").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "quote.bubble.fill").foregroundColor(.indigo)
            }
        }
        .groupBoxStyle(NativeWidgetGroupBoxStyle())
        .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        .onTapGesture { withAnimation(.spring()) { if !allExcerpts.isEmpty { curIdx = (curIdx + 1) % allExcerpts.count } } }
        .onReceive(timer) { _ in guard !allExcerpts.isEmpty else { return }; withAnimation(.spring()) { curIdx = (curIdx + 1) % allExcerpts.count } }
    }
}

// MARK: - 📚 待读队列 (极简书架)

struct FluidQueueBookshelfChart: View {
    let wantToReadBooks: [Book]
    
    var body: some View {
        let displayBooks = Array(wantToReadBooks.prefix(4))
        GroupBox {
            if displayBooks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "books.vertical").font(.system(size: 24)).foregroundColor(.secondary.opacity(0.4))
                    Text("暂无想读计划").font(.system(size: 13, weight: .medium)).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(displayBooks) { book in WantToReadBookItem(book: book).frame(maxWidth: .infinity) }
                    // 占位保证排版整齐
                    if displayBooks.count < 4 { ForEach(0..<(4 - displayBooks.count), id: \.self) { _ in Spacer().frame(maxWidth: .infinity) } }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(.top, 8)
            }
        } label: {
            HStack {
                Text("想读焦点").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "sparkles.rectangle.stack").foregroundColor(.orange)
            }
        }
        .groupBoxStyle(NativeWidgetGroupBoxStyle())
    }
}

private struct WantToReadBookItem: View {
    let book: Book
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            LocalCoverView(coverData: book.coverData, fallbackTitle: book.title ?? "")
                // ✨ 固定尺寸：宽 90，高 135 (维持 2:3 完美比例)
                .frame(width: 100, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                // ⚠️ 性能优化点：在大量封面上使用 shadow 时，如果不明确形状边界，系统会很吃力。
                // 这里的 shadow 配合固定 frame 负担极小
                .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.05), lineWidth: 0.5))
            
            VStack(alignment: .center, spacing: 4) {
                Text(book.title ?? "未知")
                    .font(.system(size: 13, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                
                Text(book.author ?? "未知")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            // 文字容器依然铺满，保证绝对居中，但受上层约束
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 🧠 知识图谱 (全宽基因彩带风)

/// 适配大宽度，采用更粗的进度条和内嵌排版的图例
struct FluidKnowledgeSpectrumCard: View {
    let readBooks: [Book]
    @State private var data: [(String, Double, Color)] = []
    let colors: [Color] = [.purple, .indigo, .teal, .orange, .blue] // 增加一个颜色以防溢出
    
    var body: some View {
        GroupBox {
            if data.isEmpty {
                VStack(spacing: 8) { Image(systemName: "chart.pie").font(.system(size: 24)).foregroundColor(.secondary.opacity(0.4)); Text("缺乏数据").font(.system(size: 13)).foregroundColor(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 24) {
                    // 1. 巨型基因彩带
                    GeometryReader { geo in
                        HStack(spacing: 4) { // 稍微大一点的间隙，增强块状感
                            ForEach(0..<data.count, id: \.self) { i in
                                Rectangle()
                                    .fill(data[i].2.gradient)
                                    .frame(width: max(0, geo.size.width * (data[i].1 / 100.0) - 4))
                            }
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 18) // 加粗高度，使其在全宽下不显得单薄
                    
                    // 2. 居中排列的精美图例墙
                    HStack(spacing: 40) { // 较大的横向间距
                        ForEach(0..<data.count, id: \.self) { i in
                            HStack(spacing: 8) {
                                Circle().fill(data[i].2).frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(data[i].0)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                    Text("\(Int(data[i].1))%")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center) // 让整个图例组居中
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
        } label: {
            HStack {
                Text("知识基因").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "chart.pie.fill").foregroundColor(.purple)
            }
        }
        .groupBoxStyle(NativeWidgetGroupBoxStyle())
        .onAppear { process() }.onChange(of: readBooks) { _, _ in process() }
    }
    
    private func process() {
        var counts: [String: Double] = [:]; var total = 0.0
        for b in readBooks {
            for t in b.tags ?? [] {
                counts[t, default: 0] += 1; total += 1
            }
        }
        guard total > 0 else { data = []; return }
        // 最多展示前 5 个标签，铺满整行
        data = counts.sorted { $0.value > $1.value }.prefix(5).enumerated().map { ($0.element.key, ($0.element.value / total) * 100.0, colors[$0.offset % colors.count]) }
    }
}

// MARK: - 📈 专属流动组件：无界动能柱状图 (FluidMomentumChart)

struct FluidMomentumChart: View {
    let allRecords: [ReadingRecord]
    @State private var chartData: [(Date, Double, Bool)] = []
    @State private var totalMinutes: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ================= 1. 顶部标题栏 (与热力图风格对齐) =================
            HStack(alignment: .bottom) {
                Text("14 DAYS MOMENTUM")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.secondary)
                    .tracking(2)
                
                Spacer()
                
                // 右侧微型统计：14天总阅读时长
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(totalMinutes)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Min")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            // ================= 2. 压扁的全宽柱状图 =================
            Chart(chartData, id: \.0) { item in
                BarMark(
                    x: .value("Date", item.0, unit: .day),
                    y: .value("Minutes", item.1)
                )
                // 今天显示蓝色渐变，过去显示灰色渐变
                .foregroundStyle(item.2 ? Color.blue.gradient : Color.secondary.opacity(0.15).gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                // 横坐标每隔一天显示一次日期，避免拥挤
                AxisMarks(preset: .aligned, values: .stride(by: .day, count: 2)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.day())
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }
                }
            }
            .chartYAxis(.hidden) // 隐藏 Y 轴，保持极简
            .frame(height: 80) // ✨ 关键点：压低高度，变成横向声波状
            .frame(maxWidth: .infinity)
        }
        .onAppear { process() }
        .onChange(of: allRecords) { _, _ in process() }
    }
    
    private func process() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var temp = [(Date, Double, Bool)]()
        var total = 0.0
        
        // 构建过去 14 天的空数据模型
        for i in (0..<14).reversed() {
            temp.append((cal.date(byAdding: .day, value: -i, to: today)!, 0, i == 0))
        }
        
        // 填充真实数据
        for r in allRecords {
            let d = cal.startOfDay(for: r.date ?? Date.distantPast)
            if let a = cal.dateComponents([.day], from: d, to: today).day, a >= 0, a < 14 {
                let mins = r.readingDuration / 60.0
                temp[13 - a].1 += mins
                total += mins
            }
        }
        
        chartData = temp
        totalMinutes = Int(total)
    }
}
#endif
