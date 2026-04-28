#if os(macOS)
import SwiftUI
import SwiftData

// MARK: - 🎨 在读焦点视图 (聚合控制台 + 全宽双轨版)

struct FluidReadingHero: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var modelContext
    
    // UI 独立悬浮状态 (锁定 Hit-box)
    @State private var isHoveringProgress = false
    @State private var isHoveringTime = false
    
    // 阅读时间状态与逻辑参数
    @State private var currentMins: Int = 0
    @State private var maxMins: Int = 10
    let step = 5
    
    var body: some View {
        let normalizedProgress = min(max(book.progress / 100.0, 0), 1.0)
        let normalizedTime = min(max(Double(currentMins) / Double(maxMins), 0), 1.0)
        let safeTitle = book.title
        
        HStack(alignment: .center, spacing: 24) {
            // ================= 1. 左侧：巨幅封面 =================
            LocalCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: safeTitle)
                .frame(width: 170, height: 245)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 12, y: 8)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                
            // ================= 2. 右侧：信息与聚合双轨区 =================
            VStack(alignment: .leading, spacing: 0) {
                Text("CURRENTLY READING")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.blue)
                    .tracking(2)
                    .padding(.bottom, 6)
                
                Text(safeTitle)
                    .font(.system(size: 36, weight: .heavy, design: .serif))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(book.author)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.top, 4)
                
                Spacer()
                
                // ================= ✨ 核心交互区：顶层控制台 + 底层双轨 =================
                VStack(alignment: .leading, spacing: 14) {
                    
                    // A. 顶层：左右分列的数字与控制台
                    HStack(alignment: .bottom) {
                        
                        // --- 左侧：总进度控制 ---
                        // ✨ 重点优化：contentShape 锁死悬浮区域，告别闪退
                        HStack(alignment: .center, spacing: 10) {
                            Text("\(Int(book.progress))%")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .contentTransition(.numericText())
                            
                            // 按钮始终存在，仅控制透明度，彻底解决 Hover Hit-box 变化问题
                            HStack(spacing: 6) {
                                ControlButton(icon: "minus") {
                                    book.progress = max(0, book.progress - 1)
                                    try? modelContext.save()
                                }
                                ControlButton(icon: "plus") {
                                    book.progress = min(100, book.progress + 1)
                                    try? modelContext.save()
                                }
                            }
                            .opacity(isHoveringProgress ? 1 : 0)
                            .offset(x: isHoveringProgress ? 0 : -5)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHoveringProgress)
                        }
                        .contentShape(Rectangle())
                        .onHover { h in isHoveringProgress = h; if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                        
                        Spacer()
                        
                        // --- 右侧：阅读时长控制 ---
                        HStack(alignment: .center, spacing: 10) {
                            HStack(spacing: 6) {
                                ControlButton(icon: "minus", action: subtractTime)
                                ControlButton(icon: "plus", action: addTime)
                            }
                            .opacity(isHoveringTime ? 1 : 0)
                            .offset(x: isHoveringTime ? 0 : 5)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHoveringTime)
                            
                            Text("\(currentMins)m")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .contentTransition(.numericText())
                        }
                        .contentShape(Rectangle())
                        .onHover { h in isHoveringTime = h; if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                    }
                    
                    // B. 底层：紧凑双轨指示器 (自研轨道，彻底消除 0% 时的圆点残留)
                    VStack(spacing: 8) {
                        CustomTrackBar(value: normalizedProgress, color: .blue)
                        CustomTrackBar(value: normalizedTime, color: .mint)
                    }
                }
            }
            .frame(height: 245)
        }
        .onAppear(perform: loadTodayData)
    }
    
    // MARK: - 逻辑与修正算法引擎
    
    private func getExactDbMinutes() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        if let record = book.readingRecords?.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            return Int(record.readingDuration / 60)
        }
        return 0
    }
    
    private func loadTodayData() {
        let exactMins = getExactDbMinutes()
        currentMins = Int(round(Double(exactMins) / Double(step))) * step
        recalculateMax()
    }
    
    private func addTime() {
        let targetMins = currentMins + step
        let delta = targetMins - getExactDbMinutes()
        writeToDatabase(deltaMinutes: delta)
        currentMins = targetMins
        recalculateMax()
        NotificationCenter.default.post(name: NSNotification.Name("RecordDidUpdate"), object: nil)
    }
    
    private func subtractTime() {
        if currentMins >= step {
            let targetMins = currentMins - step
            let delta = targetMins - getExactDbMinutes()
            writeToDatabase(deltaMinutes: delta)
            currentMins = targetMins
            recalculateMax()
        }
    }
    
    /// ✨ 呼吸感扩容算法：10分钟内满格，超过则自动扩充 10 分钟上限
    private func recalculateMax() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            if currentMins == 0 {
                maxMins = 10
            } else if currentMins % 10 == 0 {
                // 如果刚好是 10 的倍数（如 10, 20），保持满格 (100%)
                maxMins = currentMins
            } else {
                // 否则，上限扩充到下一个 10 的倍数（如 15 -> 上限 20，弹性回退至 75%）
                maxMins = ((currentMins / 10) + 1) * 10
            }
        }
    }
    
    private func writeToDatabase(deltaMinutes: Int) {
        if deltaMinutes == 0 { return }
        let today = Calendar.current.startOfDay(for: Date())
        
        if let existingRecord = book.readingRecords?.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            existingRecord.readingDuration += TimeInterval(deltaMinutes * 60)
            if existingRecord.readingDuration < 0 { existingRecord.readingDuration = 0 }
        } else if deltaMinutes > 0 {
            let newRecord = ReadingRecord(date: today, readingDuration: TimeInterval(deltaMinutes * 60), book: book)
            modelContext.insert(newRecord)
            if book.readingRecords == nil { book.readingRecords = [] }
            book.readingRecords?.append(newRecord)
        }
        try? modelContext.save()
    }
}

// MARK: - 🎨 自研进度轨道 (解决 0% 残留问题)

/// 使用 GeometryReader 制作的无死角进度条，完美支持 0 宽度隐藏及弹性动画。
private struct CustomTrackBar: View {
    let value: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // 背景槽
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
                
                // 填充带
                Capsule()
                    .fill(color)
                    // 当 value 为 0 时，宽度强制归 0，彻底隐形
                    .frame(width: max(0, geo.size.width * value))
            }
        }
        .frame(height: 10)
        // 赋予极其丝滑的灌水/退水动画
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: value)
    }
}

// MARK: - 🎨 统一样式的微型控制按钮

private struct ControlButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 26, height: 26)
                .background(Color.secondary.opacity(0.08))
                .clipShape(Circle())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 🎨 在读焦点空状态 (对齐双轨布局)

struct FluidEmptyReadingHero: View {
    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                    .frame(width: 170, height: 245)
                    .background(Color.secondary.opacity(0.02))
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
            
            VStack(alignment: .leading, spacing: 0) {
                Text("CURRENTLY READING")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.3))
                    .tracking(2)
                    .padding(.bottom, 6)
                Text("虚位以待")
                    .font(.system(size: 36, weight: .heavy, design: .serif))
                    .foregroundColor(.primary.opacity(0.4))
                    .lineLimit(2)
                Text("去书库中挑选一本开启新旅程吧")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.5))
                    .lineLimit(1)
                    .padding(.top, 4)
                
                Spacer()
                
                // 空状态对齐顶层控制台 + 底层双轨
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .bottom) {
                        Text("0%")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.3))
                        Spacer()
                        Text("0m")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                    
                    VStack(spacing: 8) {
                        CustomTrackBar(value: 0, color: .secondary.opacity(0.2))
                        CustomTrackBar(value: 0, color: .secondary.opacity(0.2))
                    }
                }
            }
            .frame(height: 245)
        }
        .padding()
    }
}

// MARK: - 预览

#Preview("有在读书籍 (顶级聚合版)") {
    FluidReadingHero(book: PreviewData.mockBook)
        .modelContainer(PreviewData.shared)
        .padding(40)
        .frame(width: 800)
}

#Preview("空状态占位") {
    FluidEmptyReadingHero()
        .padding(40)
        .frame(width: 800)
}
#endif
