#if os(iOS)
internal import Combine
import Charts
import SwiftData
import SwiftUI

#if os(iOS)
import ActivityKit // ✨ 引入灵动岛专属框架
#endif

// MARK: - 👑 2. 核心调度中心 (沉浸式主页)

struct MobileHomeView: View {
    @Query var allBooks: [Book]
    @Query var allRecords: [ReadingRecord]
    @Query var allExcerpts: [Excerpt]
    
    // 弹窗状态控制
    @State private var showAddBookSheet = false
    @State private var showSettingsSheet = false
    
    /// ✨ 智能计算：获取最近活动的在读书籍
    var activeReadingBook: Book? {
        allBooks
            .filter { $0.status == .reading }
            .max { b1, b2 in
                let date1 = b1.readingRecords?.compactMap(\.date).max() ?? b1.startTime ?? .distantPast
                let date2 = b2.readingRecords?.compactMap(\.date).max() ?? b2.startTime ?? .distantPast
                return date1 < date2
            }
    }

    var readBooks: [Book] {
        allBooks.filter { $0.status == .finished }
    }

    var unreadBooks: [Book] {
        allBooks.filter { $0.status == .unread }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // 🌟 层级 1：视觉锚点 (在读焦点)
                    if let heroBook = activeReadingBook {
                        NavigationLink(destination: MobileBookDetailView(book: heroBook)) {
                            MobileReadingHeroCard(book: heroBook)
                        }
                        .buttonStyle(.plain)
                                            
                        HStack(spacing: 16) {
                            MobileFocusTimerCard(book: heroBook, allRecords: allRecords)
                            MobileManualLogCard(defaultBook: heroBook, allBooks: allBooks)
                        }
                                            
                    } else {
                        MobileEmptyReadingCard()
                    }
                    
                    // 📊 层级 2：核心数据大盘 (完美复刻桌面端圆环看板)
                    MobileDashboardCard(allBooks: allBooks, allRecords: allRecords)
                    
                    // 🌊 层级 3：双周阅读动能 (完美复刻小组件动能图)
                    MobileMomentumChartCard(allRecords: allRecords)
                    
                    // 📚 层级 4：想读画廊 (横向滚动)
                    MobileQueueCarouselCard(unreadBooks: unreadBooks)
                    
                    // 🧠 层级 5：深度复盘区 (热力图 + 知识图谱)
                    MobileYearlyHeatmapCard(allRecords: allRecords)
                    MobileKnowledgeSpectrumCard(readBooks: readBooks)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 60)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("阅读纪元")
            .toolbar {
                // ✨ 右上角全局导航按钮
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showAddBookSheet = true }) {
                            Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                        }
                        Button(action: { showSettingsSheet = true }) {
                            Image(systemName: "gearshape.fill").foregroundColor(.secondary)
                        }
                    }
                    .font(.system(size: 20))
                }
            }
            // 💡 弹出添加书籍与设置的 Sheet
            .sheet(isPresented: $showAddBookSheet) {
                MobileBookEditorSheet()
            }
            .sheet(isPresented: $showSettingsSheet) {
                MobileSettingsView()
            }
            // 💡 全局注入你的神仙级 GroupBox 样式！
            .groupBoxStyle(NativeWidgetGroupBoxStyle())
        }
    }
}

// MARK: - 🧩 3. 极简卡片群组件

// MARK: - ⏱️ 半宽版：沉浸式番茄钟卡片 (灵动岛加持版)

struct MobileFocusTimerCard: View {
    let book: Book
    let allRecords: [ReadingRecord]
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) var scenePhase
    
    @State private var isRunning = false
    @State private var unrecordedSeconds: TimeInterval = 0
    @State private var isColonVisible = true
    @State private var backgroundDate: Date?
    @State private var currentActivity: Activity<ReadingTimerAttributes>?
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let cycleTime: TimeInterval = 20 * 60
    
    var todayRecord: ReadingRecord? {
        allRecords.first(where: { Calendar.current.isDateInToday($0.date ?? Date.distantPast) && $0.book?.id == book.id })
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
    
    var body: some View {
        GroupBox {
            VStack(spacing: 0) {
                // ================= 上部：大字号表盘 =================
                HStack(spacing: 2) {
                    Text(String(format: "%02d", Int(remainingSeconds) / 60))
                    Text(":") // ✨ 变成静态冒号，杜绝动画冲突
                        .opacity(isRunning ? 0.5 : 1.0)
                    Text(String(format: "%02d", Int(remainingSeconds) % 60))
                }
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(isRunning ? .orange : .primary.opacity(0.8))
                .contentTransition(.numericText())
                .animation(.default, value: remainingSeconds)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(maxHeight: .infinity)
                .padding(.bottom, 10)
                
                // ================= 下部：左右对称控制区 =================
                HStack {
                    Button(action: toggleTimer) {
                        ZStack {
                            Circle()
                                .fill(isRunning ? Color.orange.opacity(0.15) : Color.blue.opacity(0.1))
                            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(isRunning ? .orange : .blue)
                                .offset(x: isRunning ? 0 : 2)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 4)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(completedCycles) / 5.0)
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: completedCycles)
                        
                        Text("\(completedCycles)/5")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(completedCycles > 0 ? .orange : .secondary.opacity(0.6))
                    }
                    .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 10)
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
        } label: {
            HStack {
                Text("专注计时").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: isRunning ? "timer" : "timer.circle.fill")
                    .foregroundColor(isRunning ? .orange : .secondary)
                    .symbolEffect(.pulse, isActive: isRunning)
            }
        }
        // ✨ 1. 唤醒时对齐时间
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                let defaults = UserDefaults(suiteName: "group.com.akram.library")
                if defaults?.bool(forKey: "local_timer_isRunning") == true {
                    // 同样杜绝 1970 Bug
                    let startTimestamp = defaults?.object(forKey: "local_timer_startTime") as? Double ?? Date().timeIntervalSince1970
                    self.unrecordedSeconds = Date().timeIntervalSince(Date(timeIntervalSince1970: startTimestamp))
                }
            }
        }
        // ✨ 2. 纯粹的绝对计时器
        .onReceive(timer) { _ in
            guard isRunning && scenePhase == .active else { return }
                    
            let defaults = UserDefaults(suiteName: "group.com.akram.library")
            let isRemoteRunning = defaults?.bool(forKey: "local_timer_isRunning") ?? true
                    
            if !isRemoteRunning {
                withAnimation { self.isRunning = false }
                self.unrecordedSeconds = 0 // 锁屏那边存过库了，这里直接清零就行
                return
            }
                    
            // 实时算差值
            let startTimeStamp = defaults?.object(forKey: "local_timer_startTime") as? Double ?? Date().timeIntervalSince1970
            let absoluteStartTime = Date(timeIntervalSince1970: startTimeStamp)
            self.unrecordedSeconds = Date().timeIntervalSince(absoluteStartTime)
                    
            withAnimation(.easeInOut(duration: 0.5)) { isColonVisible.toggle() }
                    
            // 当这 20 分钟满了
            if remainingSeconds <= 0.5 {
                flushTimeToDatabase()
                updateLiveActivity()
                // ✨ 极其关键：将存完库的当前时间，设为下一个 20 分钟的新起点！
                defaults?.set(Date().timeIntervalSince1970, forKey: "local_timer_startTime")
                self.unrecordedSeconds = 0
            }
        }
    }
    
    private func toggleTimer() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isRunning.toggle()
            isColonVisible = true
        }
        if isRunning {
            startLiveActivity()
        } else {
            // 在主页点结束
            let defaults = UserDefaults(suiteName: "group.com.akram.library")
            defaults?.set(false, forKey: "local_timer_isRunning")
            defaults?.removeObject(forKey: "local_timer_startTime") // 擦除起点
                
            stopLiveActivity()
            flushTimeToDatabase() // 存入剩下的时间
            unrecordedSeconds = 0
        }
    }
    
    private func flushTimeToDatabase() {
        guard unrecordedSeconds >= 1 else { return }
        
        if let record = todayRecord {
            record.readingDuration += unrecordedSeconds
        } else {
            let newRecord = ReadingRecord(date: Date(), readingDuration: unrecordedSeconds, book: book)
            modelContext.insert(newRecord)
            if book.readingRecords == nil { book.readingRecords = [] }
            book.readingRecords?.append(newRecord)
        }
        try? modelContext.save()
    }
    
    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.akram.library")!
        let coverURL = groupURL.appendingPathComponent("current_cover.jpg")

        var finalPath: String? = nil
        if let data = book.coverData {
            try? data.write(to: coverURL)
            finalPath = coverURL.path
        }
            
        // ✨ 只同步基础的启动时间和运行状态
        let defaults = UserDefaults(suiteName: "group.com.akram.library")
        defaults?.set(true, forKey: "local_timer_isRunning")
        defaults?.set(Date().timeIntervalSince1970, forKey: "local_timer_startTime")
            
        let attributes = ReadingTimerAttributes(
            bookTitle: book.title ?? "未知书籍",
            author: book.author ?? "未知作者",
            coverFilePath: finalPath,
            bookProgress: book.progress
        )
            
        let targetEndTime = Date().addingTimeInterval(remainingSeconds)
        let state = ReadingTimerAttributes.ContentState(cycleEndTime: targetEndTime, completedCycles: completedCycles)
            
        do {
            currentActivity = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
        } catch {
            print("❌ 灵动岛启动失败: \(error)")
        }
    }
    
    private func updateLiveActivity() {
        Task {
            let targetEndTime = Date().addingTimeInterval(cycleTime)
            let state = ReadingTimerAttributes.ContentState(cycleEndTime: targetEndTime, completedCycles: completedCycles)
            await currentActivity?.update(ActivityContent(state: state, staleDate: nil))
        }
    }
    
    private func stopLiveActivity() {
        Task {
            let finalState = ReadingTimerAttributes.ContentState(cycleEndTime: Date(), completedCycles: completedCycles)
            await currentActivity?.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }
}

// MARK: - 📝 半宽版：纯视觉打卡组件

struct MobileManualLogCard: View {
    let defaultBook: Book
    let allBooks: [Book]
    @State private var showLogSheet = false
    
    var body: some View {
        GroupBox {
            Button {
                showLogSheet = true
            } label: {
                ZStack {
                    // ✨ 超大号、极简纤细风格的图标，填满整个内容区
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 75, weight: .ultraLight))
                        .foregroundColor(.indigo)
                }
                .frame(height: 100) // ✨ 与左侧计时器高度严格同步
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle()) // 确保整个留白区域都可点击
            }
            .buttonStyle(.plain) // 去除按钮默认按下时的变色干扰
        } label: {
            HStack {
                Text("补录打卡").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "plus.circle.fill").foregroundColor(.indigo)
            }
        }
        .sheet(isPresented: $showLogSheet) {
            MobileManualLogSheet(defaultBook: defaultBook, allBooks: allBooks)
        }
    }
}

/// 🌟 顶部在读焦点大卡片 (去掉了播放按钮)
struct MobileReadingHeroCard: View {
    let book: Book
    var body: some View {
        let safeTitle = book.title ?? "未知书名"
        let safeAuthor = book.author ?? "未知作者"
        let progress = Double(book.progress)
        
        GroupBox {
            HStack(alignment: .top, spacing: 20) {
                LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                    .frame(width: 90, height: 135)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 6, y: 3)
                
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(safeTitle)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Text(safeAuthor)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 16)
                    
                    // 底部：纯粹舒展的进度条
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .lastTextBaseline) {
                            Text("当前进度")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(progress))%")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(.blue)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.15))
                                Capsule().fill(Color.blue.gradient).frame(width: geo.size.width * CGFloat(progress / 100.0))
                            }
                        }.frame(height: 8)
                    }
                }
            }
        } label: {
            HStack {
                Text("在读焦点").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "book.closed.fill").foregroundColor(.blue)
            }
        }
    }
}

/// 🌟 顶部在读空状态
struct MobileEmptyReadingCard: View {
    var body: some View {
        GroupBox {
            VStack(spacing: 16) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("书海浩瀚，寻找下一段旅程")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        } label: {
            HStack {
                Text("在读焦点").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "book.closed.fill").foregroundColor(.blue)
            }
        }
    }
}

/// 📊 核心数据大盘 (完美复刻 DesktopDashboardWidget)
struct MobileDashboardCard: View {
    let allBooks: [Book]
    let allRecords: [ReadingRecord]
    
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]
    
    /// 动态提取目标，查不到给个兜底值
    var dailyGoal: Int {
        configs.first?.dailyReadingGoal ?? 30
    }

    var yearTarget: Int {
        configs.first?.yearlyBookGoal ?? 50
    }
    
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

/// 辅助子组件：复刻桌面端微型状态圆环
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

/// 📈 横向拉满的双周动能 (完美复刻 MomentumWidget)
struct MobileMomentumChartCard: View {
    let allRecords: [ReadingRecord]
    
    @State private var dailyData: [(date: Date, minutes: Double)] = []
    @State private var totalDays = 0; @State private var totalMinutes = 0; @State private var maxMinutes = 0; @State private var avgMinutes = 0
    
    var body: some View {
        GroupBox {
            VStack(spacing: 0) {
                // 上部：四大指标
                HStack(alignment: .center, spacing: 0) {
                    MomentumAppStat(title: "阅读天数", value: "\(totalDays)", unit: "天")
                    Spacer(minLength: 5)
                    MomentumAppStat(title: "总计时间", value: "\(totalMinutes)", unit: "分")
                    Spacer(minLength: 5)
                    MomentumAppStat(title: "单日最高", value: "\(maxMinutes)", unit: "分")
                    Spacer(minLength: 5)
                    MomentumAppStat(title: "日均阅读", value: "\(avgMinutes)", unit: "分")
                }
                .padding(.bottom, 16)
                
                // 下部：折线面积图
                if dailyData.isEmpty {
                    VStack { Text("暂无数据").font(.system(size: 14)).foregroundColor(.secondary) }.frame(maxWidth: .infinity, minHeight: 70)
                } else {
                    Chart(dailyData, id: \.date) { item in
                        AreaMark(x: .value("Day", item.date), y: .value("Minutes", item.minutes))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [Color.blue.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Day", item.date), y: .value("Minutes", item.minutes))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                            AxisValueLabel(format: .dateTime.day()).font(.system(size: 10, weight: .bold)).foregroundStyle(Color.secondary)
                        }
                    }
                    .frame(height: 70)
                }
            }
            .padding(.top, 4)
        } label: {
            HStack {
                Text("双周动能").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "waveform.path.ecg").foregroundColor(.blue)
            }
        }
        .onAppear { processData() }
        .onChange(of: allRecords) { _, _ in processData() }
    }
    
    private func processData() {
        let cal = Calendar.current; let today = cal.startOfDay(for: Date()); let startDate = cal.date(byAdding: .day, value: -13, to: today)!
        var dailyMap: [Date: Double] = [:]
        for record in allRecords {
            let recDay = cal.startOfDay(for: record.date ?? .distantPast)
            if recDay >= startDate, recDay <= today { dailyMap[recDay, default: 0] += (record.readingDuration / 60.0) }
        }
        
        var tempData: [(Date, Double)] = []; var daysRead = 0; var tMin = 0.0; var mMin = 0.0
        for i in 0..<14 {
            let d = cal.date(byAdding: .day, value: i, to: startDate)!
            let mins = dailyMap[d] ?? 0.0
            tempData.append((d, mins))
            if mins > 0 { daysRead += 1 }
            if mins > mMin { mMin = mins }
            tMin += mins
        }
        dailyData = tempData; totalDays = daysRead; totalMinutes = Int(tMin); maxMinutes = Int(mMin)
        avgMinutes = daysRead > 0 ? Int(tMin / Double(daysRead)) : 0
    }
}

private struct MomentumAppStat: View {
    let title: String; let value: String; let unit: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value).font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundColor(.primary)
                Text(unit).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary.opacity(0.8))
            }
        }
    }
}

/// 📚 待读画廊 (横向滚动)
struct MobileQueueCarouselCard: View {
    let unreadBooks: [Book]
    var body: some View {
        GroupBox {
            if unreadBooks.isEmpty {
                VStack { Text("暂无想读计划").font(.system(size: 14, weight: .medium)).foregroundColor(.secondary) }
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(unreadBooks.prefix(10)) { book in
                            NavigationLink(destination: MobileBookDetailView(book: book)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    LocalCoverView(coverData: book.coverData, fallbackTitle: book.title ?? "")
                                        .frame(width: 80, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                                    
                                    Text(book.title ?? "未知")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(width: 80, alignment: .leading)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 8)
            }
        } label: {
            HStack {
                Text("想读列车").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "sparkles.rectangle.stack").foregroundColor(.orange)
            }
        }
    }
}

/// 🗓️ 年度热力卡片 (完美复刻 YearlyHeatmapWidget，支持横滑)
struct MobileYearlyHeatmapCard: View {
    let allRecords: [ReadingRecord]
    @State private var heatmapColumns: [HeatmapColumn] = []
    
    struct HeatmapColumn: Identifiable { let id: Int; let days: [HeatmapDay] }
    struct HeatmapDay: Identifiable { let id = UUID(); let intensity: Double; let isFuture: Bool }
    
    var body: some View {
        GroupBox {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(heatmapColumns) { column in
                        VStack(spacing: 4) {
                            ForEach(column.days) { day in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(day.isFuture ? Color.clear : (day.intensity > 0 ? Color.indigo.opacity(day.intensity) : Color.secondary.opacity(0.15)))
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }
                }
                .padding(.top, 12)
            }
            // 自动滚动到最右边（最近日期）
            .defaultScrollAnchor(.trailing)
        } label: {
            HStack {
                Text("打卡密度").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "square.grid.3x3.fill").foregroundColor(.indigo)
            }
        }
        .onAppear { processHeatmapData() }
        .onChange(of: allRecords) { _, _ in processHeatmapData() }
    }
    
    private func processHeatmapData() {
        var cal = Calendar.current; cal.firstWeekday = 2; let today = cal.startOfDay(for: Date())
        var dailyDurations: [Date: TimeInterval] = [:]
        for record in allRecords {
            dailyDurations[cal.startOfDay(for: record.date ?? Date()), default: 0] += record.readingDuration
        }
        
        let daysToSubtract = (cal.component(.weekday, from: today) + 5) % 7
        let currentWeekStart = cal.date(byAdding: .day, value: -daysToSubtract, to: today)!
        let startDate = cal.date(byAdding: .weekOfYear, value: -51, to: currentWeekStart)! // 获取完整的 52 周
        
        var cols: [HeatmapColumn] = []
        for weekOffset in 0..<52 {
            var daysInWeek: [HeatmapDay] = []
            for dayOffset in 0..<7 {
                let date = cal.date(byAdding: .day, value: weekOffset * 7 + dayOffset, to: startDate)!
                let duration = dailyDurations[date] ?? 0
                let isFuture = date > today
                let intensity = isFuture ? 0 : (duration > 0 ? min((duration / 3600.0) * 0.7 + 0.3, 1.0) : 0)
                daysInWeek.append(HeatmapDay(intensity: intensity, isFuture: isFuture))
            }
            cols.append(HeatmapColumn(id: weekOffset, days: daysInWeek))
        }
        heatmapColumns = cols
    }
}

/// 🧠 知识图谱横条版
struct MobileKnowledgeSpectrumCard: View {
    let readBooks: [Book]
    @State private var spectrumData: [(name: String, value: Double, color: Color)] = []
    let palette: [Color] = [.purple, .indigo, .teal, .orange, .blue]
    
    var body: some View {
        GroupBox {
            VStack(spacing: 16) {
                if spectrumData.isEmpty {
                    Text("缺乏数据建立图谱").font(.system(size: 14)).foregroundColor(.secondary).frame(minHeight: 60)
                } else {
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(spectrumData, id: \.name) { item in
                                Rectangle().fill(item.color.gradient).frame(width: max(geo.size.width * CGFloat(item.value / 100.0) - 2, 0))
                            }
                        }
                        .clipShape(Capsule())
                    }.frame(height: 12)
                    
                    HStack(spacing: 16) {
                        ForEach(spectrumData, id: \.name) { item in
                            HStack(spacing: 4) {
                                Circle().fill(item.color).frame(width: 8, height: 8)
                                Text(item.name).font(.system(size: 11, weight: .bold))
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text("知识图谱").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "chart.pie.fill").foregroundColor(.purple)
            }
        }
        .onAppear { process() }
        .onChange(of: readBooks) { _, _ in process() }
    }
    
    private func process() {
        var counts: [String: Double] = [:]; var total = 0.0
        for book in readBooks {
            for tag in book.tags ?? [] {
                let c = tag.trimmingCharacters(in: .whitespaces); if !c.isEmpty { counts[c, default: 0] += 1; total += 1 }
            }
        }
        guard total > 0 else { spectrumData = []; return }
        spectrumData = counts.sorted { $0.value > $1.value }.prefix(4).enumerated().map {
            ($0.element.key, ($0.element.value / total) * 100.0, palette[$0.offset % palette.count])
        }
    }
}
#endif
