#if os(macOS)
internal import Combine
import SwiftData
import SwiftUI

// MARK: - ⏱️ 桌面级极简焦点计时器

/// 桌面端的高规格翻页风焦点时钟组件。
///
/// **核心功能：**
/// 该组件基于绝对时间循环。具备严密的后台冻结防御机制。
/// 计时结束时，严格向绑定的 `currentBook` 的今日流水中累加绝对秒数。
struct FluidFocusTimer: View {
    let allRecords: [ReadingRecord]
    let currentBook: Book?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    
    @State private var isRunning = false
    @State private var unrecordedSeconds: TimeInterval = 0
    @State private var isColonVisible = true
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let cycleTime: TimeInterval = 20 * 60
    
    var todayRecord: ReadingRecord? {
        guard let book = currentBook else { return nil }
        return allRecords.first { Calendar.current.isDateInToday($0.date ?? Date.distantPast) && $0.book?.id == book.id }
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
        VStack(spacing: 24) {
            HStack(spacing: 16) {
                GiantTimeBlock(value: minutesString, label: "MINUTES")
                Text(":").font(.system(size: 76, weight: .medium, design: .rounded)).foregroundColor(isRunning ? accentColor : .secondary.opacity(0.4)).opacity(isColonVisible ? 1.0 : 0.2).offset(y: -12)
                GiantTimeBlock(value: secondsString, label: "SECONDS")
            }
            .shadow(color: Color.black.opacity(isRunning ? 0.12 : 0.04), radius: 20, y: 10)
            
            HStack(spacing: 24) {
                Button(action: toggleTimer) {
                    ZStack {
                        Circle().fill(isRunning ? accentColor.opacity(0.15) : Color.primary.opacity(0.06)).frame(width: 44, height: 44)
                        Image(systemName: isRunning ? "pause.fill" : "play.fill").font(.system(size: 18, weight: .black)).foregroundColor(isRunning ? accentColor : .primary.opacity(0.7)).offset(x: isRunning ? 0 : 2)
                    }
                }
                .buttonStyle(PlainButtonStyle()).onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }.disabled(currentBook == nil)
                
                HStack(spacing: 12) {
                    ForEach(0 ..< 5, id: \.self) { index in
                        Circle().fill(index < completedCycles ? accentColor.gradient : Color.secondary.opacity(0.15).gradient).frame(width: 10, height: 10).shadow(color: index < completedCycles ? accentColor.opacity(0.5) : .clear, radius: 4)
                    }
                }
                .padding(.trailing, 16)
            }
            .padding(8)
            .background(Capsule().fill(colorScheme == .light ? Color.white : Color(nsColor: .controlBackgroundColor)).overlay(Capsule().stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.06), lineWidth: 0.5)))
            .shadow(color: Color.black.opacity(colorScheme == .light ? 0.08 : 0.2), radius: 12, y: 6)
        }
        .frame(height: 245, alignment: .center)
        .onChange(of: scenePhase) { _, newPhase in if newPhase == .background || newPhase == .inactive { if isRunning { flushTimeToDatabase(); isRunning = false } } }
        .onReceive(timer) { _ in guard isRunning else { return }; unrecordedSeconds += 1; withAnimation(.easeInOut(duration: 0.5)) { isColonVisible.toggle() }; if remainingSeconds == cycleTime { flushTimeToDatabase() } }
    }
    
    private func toggleTimer() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { isRunning.toggle(); isColonVisible = true }
        if !isRunning { flushTimeToDatabase() }
    }
    
    private func flushTimeToDatabase() {
        guard unrecordedSeconds >= 1, let book = currentBook else { return }
        if let record = todayRecord { record.readingDuration += unrecordedSeconds } else {
            let newRecord = ReadingRecord(date: Date(), readingDuration: unrecordedSeconds, book: book)
            modelContext.insert(newRecord)
            if book.readingRecords == nil { book.readingRecords = [] }
            book.readingRecords?.append(newRecord)
        }
        unrecordedSeconds = 0; try? modelContext.save()
    }
}

private struct GiantTimeBlock: View {
    let value: String; let label: String
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(colorScheme == .light ? Color.white : Color(nsColor: .controlBackgroundColor))
                Rectangle().fill(Color.primary.opacity(colorScheme == .light ? 0.04 : 0.1)).frame(height: 2)
                Text(value).font(.system(size: 88, weight: .bold, design: .rounded)).monospacedDigit().foregroundColor(.primary.opacity(0.85))
            }
            .frame(width: 120, height: 120)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.06), lineWidth: 0.5))
            .shadow(color: Color.black.opacity(colorScheme == .light ? 0.08 : 0.3), radius: 16, y: 8)
            Text(label).font(.system(size: 11, weight: .black, design: .rounded)).foregroundColor(.secondary.opacity(0.5)).tracking(3)
        }
    }
}
#endif
