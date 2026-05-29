#if os(iOS)
import SwiftUI
import SwiftData
internal import Combine

// MARK: - 阅读计时卡片

struct MobileReadingTimerCard: View {
    let book: Book?
    let todayTotalSeconds: TimeInterval

    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var timerStore = ReadingTimerStore.shared

    @State private var elapsedSeconds: TimeInterval = 0
    @State private var isTimedDurationPresented = false
    @State private var isTimerCompletePresented = false
    @State private var isManualEntryPresented = false

    @State private var timedDurationMinutes = 30
    @State private var manualMinutes = 25
    @State private var manualProgressDraft = ReadingProgressDraft()
    @State private var timerProgressDraft = ReadingProgressDraft()
    @State private var pendingTimerEndAt: Date?

    private let timer = Timer.publish(every: 1, on: .main, in: .default).autoconnect()

    private var isTiming: Bool {
        guard let book else { return false }
        return timerStore.isTiming(bookID: book.id)
    }

    private var dailyTarget: Int { 30 }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack {
                    Text("阅读计时")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "timer")
                        .foregroundColor(AppColors.readingAmber)
                }
                VStack(spacing: AppSpacing.s) {
                    if let book {
                        gaugeSection(for: book)
                        buttonSection(for: book)
                    } else {
                        emptyState
                    }
                }
            }
        }
        .onReceive(timer) { now in
            guard let book else { return }
            elapsedSeconds = timerStore.elapsedSeconds(for: book.id, now: now)
        }
        .onChange(of: book?.id) { _, _ in
            pendingTimerEndAt = nil
            if let book {
                manualProgressDraft = ReadingProgressDraft.sessionDefault(for: book)
                timerProgressDraft = ReadingProgressDraft.sessionDefault(for: book)
                elapsedSeconds = timerStore.elapsedSeconds(for: book.id)
            }
        }
        .onAppear {
            guard let book else { return }
            elapsedSeconds = timerStore.elapsedSeconds(for: book.id)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            timerStore.syncFromDefaults()
            guard let book else { return }
            elapsedSeconds = timerStore.elapsedSeconds(for: book.id)
        }
        .sheet(isPresented: Binding(
            get: { isTimedDurationPresented && book != nil },
            set: { isTimedDurationPresented = $0 }
        )) {
            if let book { timedDurationSheet(for: book) }
        }
        .sheet(isPresented: Binding(
            get: { isTimerCompletePresented && book != nil },
            set: { isTimerCompletePresented = $0 }
        )) {
            if let book { timerCompleteSheet(for: book) }
        }
        .sheet(isPresented: Binding(
            get: { isManualEntryPresented && book != nil },
            set: { isManualEntryPresented = $0 }
        )) {
            if let book { manualEntrySheet(for: book) }
        }
    }

    // MARK: - 表盘区域

    private func gaugeSection(for book: Book) -> some View {
        ReadingTimerGauge(
            todayTotalSeconds: todayTotalSeconds,
            dailyTargetMinutes: dailyTarget,
            elapsedSeconds: elapsedSeconds,
            timedTargetSeconds: timerStore.targetDuration,
            isTiming: isTiming
        )
        .frame(maxWidth: .infinity)
        .frame(height: 110)
    }

    // MARK: - 按钮区域

    private func buttonSection(for book: Book) -> some View {
        VStack(spacing: 10) {
            if isTiming {
                Button {
                    stopTimer(for: book)
                } label: {
                    Text("结束阅读")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .appCapsuleStyle(tint: AppColors.danger, fillOpacity: 1)
            } else {
                HStack(spacing: 10) {
                    Button {
                        startFreeTimer(for: book)
                    } label: {
                        Text("开始阅读")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .appCapsuleStyle(tint: AppColors.readingAmber, fillOpacity: 1)

                    Button {
                        timedDurationMinutes = 30
                        isTimedDurationPresented = true
                    } label: {
                        Text("定时阅读")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .appCapsuleStyle(tint: AppColors.readingAmber, fillOpacity: 1)
                }
            }

            Button {
                manualProgressDraft = ReadingProgressDraft.sessionDefault(for: book)
                manualMinutes = 25
                isManualEntryPresented = true
            } label: {
                Text("手动录入")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .appCapsuleStyle(tint: AppColors.success, fillOpacity: 1)
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        Text("暂无在读")
            .font(AppTypography.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - 定时阅读 Sheet

    private func timedDurationSheet(for book: Book) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("设定阅读时长")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    ForEach([15, 25, 30, 45, 60], id: \.self) { minutes in
                        Button {
                            timedDurationMinutes = minutes
                        } label: {
                            Text("\(minutes)分")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .frame(height: 32)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(timedDurationMinutes == minutes ? Color.white : AppColors.readingAmber)
                        .appCapsuleStyle(
                            tint: AppColors.readingAmber,
                            fillOpacity: timedDurationMinutes == minutes ? 1 : 0.10
                        )
                    }
                }

                HStack(spacing: 20) {
                    Button {
                        timedDurationMinutes = max(5, timedDurationMinutes - 5)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(AppColors.readingAmber)
                    }
                    .buttonStyle(.plain)

                    Text("\(timedDurationMinutes) 分钟")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)

                    Button {
                        timedDurationMinutes = min(240, timedDurationMinutes + 5)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(AppColors.readingAmber)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .appInnerBlockStyle(cornerRadius: 12)

                Spacer()

                Button {
                    isTimedDurationPresented = false
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    timerStore.startTimed(bookID: book.id, duration: TimeInterval(timedDurationMinutes * 60))
                    elapsedSeconds = 0
                    requestLiveActivity(for: book)
                } label: {
                    Text("开始计时")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .appCapsuleStyle(tint: AppColors.readingAmber, fillOpacity: 1)
            }
            .padding(20)
            .navigationTitle("定时阅读")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isTimedDurationPresented = false
                    }
                }
            }
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 计时完成 Sheet

    private func timerCompleteSheet(for book: Book) -> some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("结束本次阅读")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)

                    Text(formattedDuration(elapsedSeconds))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.readingAmber)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .appInnerBlockStyle(cornerRadius: 12)

                ReadingProgressInputView(
                    draft: $timerProgressDraft,
                    mode: .sessionUpdate,
                    lockedUnit: true,
                    minimumCurrentAmount: book.currentAmount
                )

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    finishTimerSession(for: book)
                } label: {
                    Text("完成记录")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .appCapsuleStyle(tint: AppColors.readingAmber, fillOpacity: 1)
            }
            .padding(20)
            .navigationTitle("记录进度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isTimerCompletePresented = false
                        pendingTimerEndAt = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 手动录入 Sheet

    private func manualEntrySheet(for book: Book) -> some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("本次阅读时长")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 20) {
                    Button {
                        manualMinutes = max(5, manualMinutes - 5)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(AppColors.readingAmber)
                    }
                    .buttonStyle(.plain)

                    Text("\(manualMinutes) 分钟")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)

                    Button {
                        manualMinutes = min(240, manualMinutes + 5)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(AppColors.readingAmber)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .appInnerBlockStyle(cornerRadius: 12)

                Divider().opacity(0.3)

                ReadingProgressInputView(
                    draft: $manualProgressDraft,
                    mode: .sessionUpdate,
                    lockedUnit: true,
                    minimumCurrentAmount: book.currentAmount
                )

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    insertManualSession(for: book)
                } label: {
                    Text("保存记录")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .appCapsuleStyle(tint: AppColors.readingAmber, fillOpacity: 1)
            }
            .padding(20)
            .navigationTitle("手动录入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isManualEntryPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 计时控制方法

    private func startFreeTimer(for book: Book) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        timerStore.start(bookID: book.id)
        elapsedSeconds = 0
        requestLiveActivity(for: book)
    }

    private func stopTimer(for book: Book) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        pendingTimerEndAt = Date()
        timerProgressDraft = ReadingProgressDraft.sessionDefault(for: book)
        elapsedSeconds = timerStore.elapsedSeconds(for: book.id, now: pendingTimerEndAt ?? Date())
        isTimerCompletePresented = true
    }

    private func finishTimerSession(for book: Book) {
        guard let timerStartedAt = timerStore.startedAt(for: book.id),
              let endAt = pendingTimerEndAt else { return }

        var normalized = timerProgressDraft
        normalized.normalize()

        do {
            try ReadingDataService.shared.insertTimerReadingSession(
                for: book,
                startedAt: timerStartedAt,
                endedAt: endAt,
                endAmount: normalized.currentAmount,
                context: modelContext
            )
            endLiveActivity(for: book, endedAt: endAt)
            timerStore.cancel()
            pendingTimerEndAt = nil
            elapsedSeconds = 0
            isTimerCompletePresented = false
        } catch {
            print("❌ 计时阅读记录保存失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Live Activity

    #if os(iOS)
    private func requestLiveActivity(for book: Book) {
        guard let startedAt = timerStore.startedAt else { return }
        let elapsedSeconds = Date().timeIntervalSince(startedAt)
        let attrs = ReadingTimerAttributes(
            bookTitle: book.title,
            bookAuthor: book.author
        )
        let state = ReadingTimerAttributes.ContentState(
            startedAt: startedAt,
            targetSeconds: timerStore.targetDuration,
            elapsedSeconds: elapsedSeconds,
            dailyTargetMinutes: dailyTarget,
            todayTotalSeconds: todayTotalSeconds,
            progressAmount: book.currentAmount,
            progressUnit: book.progressUnit.longDisplayName,
            totalAmount: book.totalAmount,
            coverData: coverThumbnail(from: book.coverData)
        )
        LiveActivityManager.shared.request(attributes: attrs, contentState: state)
    }

    private func endLiveActivity(for book: Book, endedAt: Date) {
        let state = ReadingTimerAttributes.ContentState(
            startedAt: timerStore.startedAt ?? Date(),
            targetSeconds: timerStore.targetDuration,
            elapsedSeconds: elapsedSeconds,
            dailyTargetMinutes: dailyTarget,
            todayTotalSeconds: todayTotalSeconds + elapsedSeconds,
            progressAmount: book.currentAmount,
            progressUnit: book.progressUnit.longDisplayName,
            totalAmount: book.totalAmount,
            coverData: coverThumbnail(from: book.coverData)
        )
        LiveActivityManager.shared.end(contentState: state)
    }

    private func coverThumbnail(from imageData: Data?) -> Data? {
        guard let data = imageData, let image = UIImage(data: data) else { return nil }
        let maxSize: CGFloat = 60
        let size = image.size
        let scale = min(maxSize / max(size.width, size.height), 1)
        guard scale < 1 else { return data }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1)
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()?.jpegData(compressionQuality: 0.4)
    }
    #else
    private func requestLiveActivity(for book: Book) {}
    private func endLiveActivity(for book: Book, endedAt: Date) {}
    #endif

    private func insertManualSession(for book: Book) {
        let endedAt = Date()
        let duration = TimeInterval(manualMinutes * 60)
        let startedAt = endedAt.addingTimeInterval(-duration)

        var normalized = manualProgressDraft
        normalized.normalize()

        do {
            try ReadingDataService.shared.insertManualReadingSession(
                for: book,
                startedAt: startedAt,
                duration: duration,
                progressUnit: normalized.unit,
                startAmount: book.currentAmount,
                endAmount: normalized.currentAmount,
                context: modelContext
            )
            isManualEntryPresented = false
        } catch {
            print("❌ 手动录入记录保存失败: \(error.localizedDescription)")
        }
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let minutes = total / 60
        let secs = total % 60
        return "\(String(format: "%02d", minutes)):\(String(format: "%02d", secs))"
    }
}

#if DEBUG
private struct PreviewTimerCard: View {
    var body: some View {
        PreviewWithBook(title: "三体", author: "刘慈欣", currentAmount: 156) { book in
            MobileReadingTimerCard(book: book, todayTotalSeconds: 1200)
                .padding()
                .background(AppColors.primaryBackground(for: .light))
        }
    }
}

#Preview("阅读计时卡") {
    PreviewTimerCard()
        .modelContainer(previewModelContainer)
}

#Preview("阅读计时卡 - 空状态") {
    MobileReadingTimerCard(book: nil, todayTotalSeconds: 0)
        .padding()
        .background(AppColors.primaryBackground(for: .light))
}
#endif


#endif
