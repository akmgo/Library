#if os(macOS)
internal import Combine
import SwiftData
import SwiftUI

// MARK: - 🎨 在读焦点视图

struct ReadingHero: View {
    @Bindable var book: Book
    let secondaryBooks: [Book]
    let onOpenBookDetail: () -> Void
    let onSelectSecondaryBook: (Book) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let heroContentHeight: CGFloat = 238
    private let secondaryRowHeight: CGFloat = 68
    private let secondaryRowSpacing: CGFloat = 17
    private let secondaryListWidth: CGFloat = 220
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                Text("当前在读")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "book.fill")
                    .foregroundColor(AppColors.readingAmber)
            }

            HStack(alignment: .center, spacing: 24) {
                Button(action: onOpenBookDetail) {
                    BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                        .frame(width: 166, height: heroContentHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color.black.opacity(0.15), radius: 12, y: 8)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.title)
                            .font(.system(size: 31, weight: .heavy, design: .serif))
                            .foregroundColor(.primary)
                            .lineLimit(2)

                        Text(book.author.isEmpty ? "未知作者" : book.author)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    progressRow
                }
                .frame(height: heroContentHeight)
                .frame(maxWidth: .infinity, alignment: .leading)

                secondaryReadingList
                    .frame(width: secondaryListWidth, height: heroContentHeight)
            }
        }
        .glassCard(cornerRadius: AppRadius.panel)
    }

    private var secondaryReadingList: some View {
        VStack(spacing: secondaryRowSpacing) {
            ForEach(secondaryBooks) { candidate in
                SecondaryReadingBookRow(book: candidate) {
                    onSelectSecondaryBook(candidate)
                }
                .frame(height: secondaryRowHeight)
            }

            if secondaryBooks.count < 3 {
                ForEach(0 ..< (3 - secondaryBooks.count), id: \.self) { _ in
                    RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                        .fill(AppColors.innerBlock(for: colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                                .stroke(AppColors.innerStroke(for: colorScheme), lineWidth: 1)
                        )
                        .frame(maxWidth: 300)
                        .frame(height: secondaryRowHeight)
                }
            }
        }
        .frame(height: heroContentHeight)
    }

    private var progressRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(progressDetailText)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.82))
                    .lineLimit(1)

                Spacer()

                Text("\(Int(book.progressRatio * 100))%")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.readingAmber)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))

                    Capsule()
                        .fill(AppColors.readingAmber)
                        .frame(width: proxy.size.width * book.progressRatio)
                        .animation(.appContentFade, value: book.progressRatio)
                }
            }
            .frame(height: 8)
        }
    }
    
    private var progressDetailText: String {
        guard book.totalAmount > 0 else {
            switch book.progressUnit {
            case .page:
                return "页数未设置"
            case .chapter:
                return "章节数未设置"
            case .percent:
                return "当前进度"
            }
        }

        switch book.progressUnit {
        case .page:
            return "\(Int(book.currentAmount)) / \(Int(book.totalAmount)) 页"
        case .chapter:
            return "\(Int(book.currentAmount)) / \(Int(book.totalAmount)) 章"
        case .percent:
            return "当前进度"
        }
    }
}

struct ReadingTimerCard: View {
    @Bindable var book: Book
    let todayTotalSeconds: TimeInterval

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var timerStore = ReadingTimerStore.shared
    @State private var elapsedSeconds: TimeInterval = 0
    @State private var isManualPopoverPresented = false
    @State private var isTimerProgressPopoverPresented = false
    @State private var isTimedDurationPopoverPresented = false
    @State private var timedDurationMinutes = 30
    @State private var manualMinutes = 25
    @State private var manualProgressDraft: ReadingProgressDraft
    @State private var timerProgressDraft: ReadingProgressDraft
    @State private var pendingTimerEndAt: Date?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // 和 ReadingHero 的 heroContentHeight 保持一致
    private let timerContentHeight: CGFloat = 238
    private let controlHeight: CGFloat = 44
    private let controlSpacing: CGFloat = 10
    private let gaugeHeight: CGFloat = 118

    init(book: Book, todayTotalSeconds: TimeInterval) {
        self.book = book
        self.todayTotalSeconds = todayTotalSeconds
        _manualProgressDraft = State(initialValue: ReadingProgressDraft.sessionDefault(for: book))
        _timerProgressDraft = State(initialValue: ReadingProgressDraft.sessionDefault(for: book))
    }

    private var isTiming: Bool {
        timerStore.isTiming(bookID: book.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                Text("阅读计时")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "timer")
                    .foregroundColor(AppColors.readingAmber)
            }

            timerContent
                .frame(height: timerContentHeight)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .onReceive(timer) { now in
            elapsedSeconds = timerStore.elapsedSeconds(for: book.id, now: now)
        }
        .onChange(of: book.id) { _, _ in
            pendingTimerEndAt = nil
            manualProgressDraft = ReadingProgressDraft.sessionDefault(for: book)
            timerProgressDraft = ReadingProgressDraft.sessionDefault(for: book)
            elapsedSeconds = timerStore.elapsedSeconds(for: book.id)
        }
        .onAppear {
            elapsedSeconds = timerStore.elapsedSeconds(for: book.id)
        }
    }

    private var timerContent: some View {
        VStack(alignment: .center, spacing: 0) {
            ReadingTimerGauge(
                todayTotalSeconds: todayTotalSeconds,
                dailyTargetMinutes: 30,
                elapsedSeconds: elapsedSeconds,
                timedTargetSeconds: timerStore.targetDuration,
                isTiming: isTiming
            )
            .frame(maxWidth: .infinity)
            .frame(height: gaugeHeight)

            Spacer(minLength: 0)

            VStack(spacing: controlSpacing) {
                if isTiming {
                    Button {
                        stopTimer()
                    } label: {
                        Text("结束阅读")
                            .font(.system(size: 17, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: controlHeight)
                    }
                    .buttonStyle(
                        ReadingHeroCapsuleButtonStyle(
                            tint: AppColors.danger,
                            isFilled: true
                        )
                    )
                    .popover(isPresented: $isTimerProgressPopoverPresented, arrowEdge: .bottom) {
                        timerCompletionPopover
                    }
                } else {
                    HStack(spacing: controlSpacing) {
                        Button {
                            startFreeTimer()
                        } label: {
                            Text("开始阅读")
                                .font(.system(size: 17, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: controlHeight)
                        }
                        .buttonStyle(
                            ReadingHeroCapsuleButtonStyle(
                                tint: AppColors.readingAmber,
                                isFilled: true
                            )
                        )

                        Button {
                            timedDurationMinutes = 30
                            isTimedDurationPopoverPresented = true
                        } label: {
                            Text("定时阅读")
                                .font(.system(size: 17, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: controlHeight)
                        }
                        .buttonStyle(
                            ReadingHeroCapsuleButtonStyle(
                                tint: AppColors.readingAmber,
                                isFilled: true
                            )
                        )
                        .popover(isPresented: $isTimedDurationPopoverPresented, arrowEdge: .bottom) {
                            timedDurationPopover
                        }
                    }
                }

                Button {
                    manualProgressDraft = ReadingProgressDraft.sessionDefault(for: book)
                    isManualPopoverPresented = true
                } label: {
                    Text("手动录入")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: controlHeight)
                }
                .buttonStyle(
                    ReadingHeroCapsuleButtonStyle(
                        tint: AppColors.success,
                        isFilled: true
                    )
                )
                .popover(isPresented: $isManualPopoverPresented, arrowEdge: .bottom) {
                    manualSessionPopover
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: timerContentHeight)
        .frame(maxWidth: .infinity)
    }

    private var manualSessionPopover: some View {
        VStack(alignment: .center, spacing: 14) {
            Text("本次阅读时长")
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                Button {
                    manualMinutes = max(5, manualMinutes - 5)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                Text("\(manualMinutes) 分钟")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)

                Button {
                    manualMinutes = min(240, manualMinutes + 5)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.m)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .appInnerBlockStyle(cornerRadius: AppRadius.m)

            Divider().opacity(0.28)

            ReadingProgressInputView(
                draft: $manualProgressDraft,
                mode: .sessionUpdate,
                lockedUnit: true,
                minimumCurrentAmount: book.currentAmount
            )

            Button {
                insertManualSession()
            } label: {
                Text("保存记录")
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(AppColors.readingAmber, in: Capsule())
            .keyboardShortcut(.defaultAction)

            Button("取消") {
                isManualPopoverPresented = false
            }
            .keyboardShortcut(.cancelAction)
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        .padding(18)
        .frame(width: 320)
    }

    private var timerCompletionPopover: some View {
        VStack(alignment: .center, spacing: 14) {
            VStack(alignment: .center, spacing: 4) {
                Text("结束本次阅读")
                    .font(.system(size: 14, weight: .bold))

                Text(formattedDuration(elapsedSeconds))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.readingAmber)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .appInnerBlockStyle(cornerRadius: AppRadius.m)

            ReadingProgressInputView(
                draft: $timerProgressDraft,
                mode: .sessionUpdate,
                lockedUnit: true,
                minimumCurrentAmount: book.currentAmount
            )

            Button {
                finishTimerSession()
            } label: {
                Text("完成记录")
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(AppColors.readingAmber, in: Capsule())
            .keyboardShortcut(.defaultAction)

            Button("取消") {
                isTimerProgressPopoverPresented = false
                pendingTimerEndAt = nil
            }
            .keyboardShortcut(.cancelAction)
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        .padding(18)
        .frame(width: 320)
    }

    private var timedDurationPopover: some View {
        VStack(alignment: .center, spacing: 14) {
            Text("设定阅读时长")
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                ForEach([15, 25, 30, 45, 60], id: \.self) { minutes in
                    Button {
                        timedDurationMinutes = minutes
                    } label: {
                        Text("\(minutes)分")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(timedDurationMinutes == minutes ? Color.white : AppColors.readingAmber)
                    .background(
                        timedDurationMinutes == minutes
                            ? AppColors.readingAmber
                            : AppColors.readingAmber.opacity(0.1),
                        in: Capsule()
                    )
                }
            }

            HStack(spacing: 16) {
                Button {
                    timedDurationMinutes = max(5, timedDurationMinutes - 5)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                Text("\(timedDurationMinutes) 分钟")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)

                Button {
                    timedDurationMinutes = min(240, timedDurationMinutes + 5)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.m)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .appInnerBlockStyle(cornerRadius: AppRadius.m)

            Button {
                isTimedDurationPopoverPresented = false
                timerStore.startTimed(bookID: book.id, duration: TimeInterval(timedDurationMinutes * 60))
                elapsedSeconds = 0
            } label: {
                Text("开始计时")
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(AppColors.readingAmber, in: Capsule())
            .keyboardShortcut(.defaultAction)

            Button("取消") {
                isTimedDurationPopoverPresented = false
            }
            .keyboardShortcut(.cancelAction)
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        .padding(18)
        .frame(width: 300)
    }

    private func startFreeTimer() {
        timerStore.start(bookID: book.id)
        elapsedSeconds = 0
    }

    private func stopTimer() {
        pendingTimerEndAt = Date()
        timerProgressDraft = ReadingProgressDraft.sessionDefault(for: book)
        elapsedSeconds = timerStore.elapsedSeconds(for: book.id, now: pendingTimerEndAt ?? Date())
        isTimerProgressPopoverPresented = true
    }

    private func finishTimerSession() {
        guard let timerStartedAt = timerStore.startedAt(for: book.id), let pendingTimerEndAt else { return }

        var normalized = timerProgressDraft
        normalized.normalize()

        try? ReadingDataService.shared.insertTimerReadingSession(
            for: book,
            startedAt: timerStartedAt,
            endedAt: pendingTimerEndAt,
            endAmount: normalized.currentAmount,
            context: modelContext
        )

        timerStore.cancel()
        self.pendingTimerEndAt = nil
        elapsedSeconds = 0
        isTimerProgressPopoverPresented = false
    }

    private func insertManualSession() {
        let endedAt = Date()
        let duration = TimeInterval(manualMinutes * 60)
        let startedAt = endedAt.addingTimeInterval(-duration)

        var normalized = manualProgressDraft
        normalized.normalize()

        try? ReadingDataService.shared.insertManualReadingSession(
            for: book,
            startedAt: startedAt,
            duration: duration,
            progressUnit: book.progressUnit,
            startAmount: book.currentAmount,
            endAmount: normalized.currentAmount,
            context: modelContext
        )

        isManualPopoverPresented = false
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let minutes = total / 60
        let secs = total % 60

        if minutes >= 60 {
            let hours = minutes / 60
            return "\(hours):\(String(format: "%02d", minutes % 60))"
        }

        return "\(String(format: "%02d", minutes)):\(String(format: "%02d", secs))"
    }
}

private struct SecondaryReadingBookRow: View {
    @Bindable var book: Book
    let onSelect: () -> Void
    private let contentHeight: CGFloat = 56

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                .frame(width: 38, height: contentHeight)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 12) {
                Text(book.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(AppColors.readingAmber.opacity(0.82))
                            .frame(width: proxy.size.width * book.progressRatio)
                    }
                }
                .frame(height: 8)
            }
            .frame(height: contentHeight, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onSelect) {
                Image(systemName: "arrow.left.circle.fill")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(AppColors.readingAmber)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: 300, maxHeight: .infinity)
        .appInnerBlockStyle(cornerRadius: AppRadius.m)
    }
}

private struct ReadingHeroCapsuleButtonStyle: ButtonStyle {
    let tint: Color
    let isFilled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isFilled ? Color.white : tint)
            .background(
                Capsule()
                    .fill(isFilled ? tint.opacity(configuration.isPressed ? 0.82 : 1) : tint.opacity(configuration.isPressed ? 0.18 : 0.11))
            )
            .overlay(
                Capsule()
                    .stroke(isFilled ? Color.clear : tint.opacity(0.28), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 🎨 空状态视图

struct EmptyReadingHero: View {
    @Environment(\.colorScheme) private var colorScheme

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
                
                Text("虚位以待")
                    .font(.system(size: 36, weight: .heavy, design: .serif))
                    .foregroundColor(.primary.opacity(0.4))
                    .lineLimit(2)
                
                Text("去书库中挑选一本开启新旅程吧")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.5))
                    .lineLimit(1)
                    .padding(.top, 4)
            }
            .frame(height: 245)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, 16)
        .background(AppColors.innerSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
        .glassEffect(in: .rect(cornerRadius: AppRadius.panel))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous)
                .stroke(AppColors.innerStroke(for: colorScheme), lineWidth: 1)
        )
    }
}

struct EmptyReadingTimerCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                Text("阅读计时")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.5))

                Spacer()

                Image(systemName: "timer")
                    .foregroundColor(AppColors.readingAmber.opacity(0.45))
            }

            Spacer()

            VStack(spacing: 12) {
                Text("00:00")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary.opacity(0.45))

                Text("选择一本在读书籍后开始计时")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.55))
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
        .glassCard(cornerRadius: AppRadius.panel)
    }
}

struct ReadingHero_Previews: PreviewProvider {

    static var previews: some View {

        Group {

            ReadingHero(

                book: sampleBook,

                secondaryBooks: [sampleBook2, sampleBook3, sampleBook4],

                onOpenBookDetail: {},

                onSelectSecondaryBook: { _ in }

            )

            .previewDisplayName("主在读示例")

            EmptyReadingHero()

                .previewDisplayName("空状态示例")

        }

        .frame(width: 1200, height: 400)

        .padding()

        .previewLayout(.sizeThatFits)

    }

    static var sampleBook: Book {

        Book(title: "置身事内",

             author: "兰小欢",

             totalAmount: 356,

             currentAmount: 86)

    }

    static var sampleBook2: Book {

        Book(title: "人类简史",

             author: "尤瓦尔·赫拉利",

             totalAmount: 100,

             currentAmount: 42)

    }

    static var sampleBook3: Book {

        Book(title: "活着",

             author: "余华",

             totalAmount: 100,

             currentAmount: 18)

    }

    static var sampleBook4: Book {

        Book(title: "思考，快与慢",

             author: "丹尼尔·卡尼曼",

             totalAmount: 100,

             currentAmount: 61)

    }

}

#if DEBUG
struct ReadingTimerGauge_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 18) {
                ReadingTimerGauge(
                    todayTotalSeconds: 18 * 60 + 36,
                    dailyTargetMinutes: 30,
                    elapsedSeconds: 0,
                    timedTargetSeconds: nil,
                    isTiming: false
                )

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Text("开始阅读")
                            .font(.system(size: 17, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(.white)
                            .background(AppColors.readingAmber, in: Capsule())

                        Text("定时阅读")
                            .font(.system(size: 17, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(.white)
                            .background(AppColors.warning, in: Capsule())
                    }

                    Text("手动录入")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 220, height: 48)
                        .foregroundStyle(.white)
                        .background(AppColors.success, in: Capsule())
                }
            }
            .padding(AppSpacing.xl)
            .background(
                AppColors.secondaryBackground(for: .light).opacity(0.72),
                in: RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous)
            )
            .previewDisplayName("仪表盘计时器 · 浅色")

            VStack(spacing: 18) {
                ReadingTimerGauge(
                    todayTotalSeconds: 42 * 60 + 12,
                    dailyTargetMinutes: 60,
                    elapsedSeconds: 22 * 60 + 45,
                    timedTargetSeconds: 60 * 60,
                    isTiming: true
                )

                VStack(spacing: 12) {
                    Text("结束阅读")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 220, height: 48)
                        .foregroundStyle(.white)
                        .background(AppColors.danger, in: Capsule())

                    Text("手动录入")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 220, height: 48)
                        .foregroundStyle(.white)
                        .background(AppColors.success, in: Capsule())
                }
            }
            .padding(AppSpacing.xl)
            .background(
                AppColors.secondaryBackground(for: .dark).opacity(0.72),
                in: RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous)
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("仪表盘计时器 · 深色")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

struct ReadingTimerCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ReadingTimerCard(
                book: Book(
                    title: "置身事内",
                    author: "兰小欢",
                    status: .reading,
                    progressUnit: .page,
                    totalAmount: 356,
                    currentAmount: 86
                ),
                todayTotalSeconds: 18 * 60 + 36
            )
            .frame(width: 284, height: 300)
            .padding()
            .previewDisplayName("阅读计时卡片")

            EmptyReadingTimerCard()
                .frame(width: 284, height: 300)
                .padding()
                .previewDisplayName("阅读计时空状态")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif

#endif
