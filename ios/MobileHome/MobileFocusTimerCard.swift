#if os(iOS)
import SwiftUI
import SwiftData
import ActivityKit
internal import Combine

// MARK: - ⏱️ iOS 专属沉浸式焦点计时器

/// 负责控制当前阅读秒数流逝，并接管 iOS `ActivityKit` 的半宽计时器卡片。
///
/// **核心机制与安全防线：**
/// 1. **状态脱水**：采用 `UserDefaults` 组通信保存启动的绝对时间戳 (`startTime`)。无论 App 被杀后台还是处于 `inactive`，时间的计算绝不丢失。
/// 2. **番茄钟循环**：具备 20 分钟满一圈的切分机制，每满一圈自动触发一次无感存库。
/// 3. **灵动岛桥接**：通过 `startLiveActivity()` 方法，将当前书籍的封面图片存入 `AppGroup` 共享沙盒目录，并优雅唤起锁屏实时活动与灵动岛进程。
struct MobileFocusTimerCard: View {
    let book: Book
    let allRecords: [ReadingRecord]
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) var scenePhase
    
    @State private var isRunning = false
    @State private var unrecordedSeconds: TimeInterval = 0
    @State private var isColonVisible = true
    
    /// 维持对当前运行中的 `Live Activity` 实例的强引用，以供结束时安全注销。
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
                    Text(":") // 变成静态冒号，杜绝动画冲突引起的布局抖动
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
                    // 同样杜绝 1970 纪元返回 Bug
                    let startTimestamp = defaults?.object(forKey: "local_timer_startTime") as? Double ?? Date().timeIntervalSince1970
                    self.unrecordedSeconds = Date().timeIntervalSince(Date(timeIntervalSince1970: startTimestamp))
                }
            }
        }
        // ✨ 2. 纯粹的绝对计时器引擎
        .onReceive(timer) { _ in
            guard isRunning && scenePhase == .active else { return }
                    
            let defaults = UserDefaults(suiteName: "group.com.akram.library")
            let isRemoteRunning = defaults?.bool(forKey: "local_timer_isRunning") ?? true
                    
            if !isRemoteRunning {
                withAnimation { self.isRunning = false }
                self.unrecordedSeconds = 0 // 锁屏那边已经存过库了，这里直接清零就行
                return
            }
                    
            // 实时利用原子钟求差值
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
    
    // MARK: - 内部控制与 ActivityKit 指令
    
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
    
    /// 唤起灵动岛及锁屏实时活动
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
    
    /// 当满足一轮番茄钟时刷新灵动岛进度数据
    private func updateLiveActivity() {
        Task {
            let targetEndTime = Date().addingTimeInterval(cycleTime)
            let state = ReadingTimerAttributes.ContentState(cycleEndTime: targetEndTime, completedCycles: completedCycles)
            await currentActivity?.update(ActivityContent(state: state, staleDate: nil))
        }
    }
    
    /// 安全结束并销毁灵动岛实例
    private func stopLiveActivity() {
        Task {
            let finalState = ReadingTimerAttributes.ContentState(cycleEndTime: Date(), completedCycles: completedCycles)
            await currentActivity?.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }
}
#endif
