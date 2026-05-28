#if os(iOS)
import ActivityKit
import SwiftUI
import WidgetKit
import UIKit

// MARK: - Shared Style

private let readingAccentColor = AppColors.readingAmber

// MARK: - Lock Screen Live Activity View

private struct ReadingTimerLiveActivityView: View {
    let context: ActivityViewContext<ReadingTimerAttributes>

    private var state: ReadingTimerAttributes.ContentState { context.state }
    private var attrs: ReadingTimerAttributes { context.attributes }

    private let lockScreenTimerWidth: CGFloat = 78
    private let lockScreenTimerTrailingInset: CGFloat = -2

    private var isTimedMode: Bool {
        state.targetSeconds != nil
    }

    private var readingProgress: Double {
        guard state.totalAmount > 0 else { return 0 }
        return min(max(state.progressAmount / state.totalAmount, 0), 1)
    }

    private var timerProgress: Double {
        guard let target = state.targetSeconds, target > 0 else {
            return readingProgress
        }

        return min(max(state.elapsedSeconds / target, 0), 1)
    }

    private var displayedProgress: Double {
        isTimedMode ? timerProgress : readingProgress
    }

    private var displayedProgressPercent: Int {
        Int(displayedProgress * 100)
    }

    private var readingProgressText: String {
        "\(Int(state.progressAmount)) / \(Int(state.totalAmount)) \(state.progressUnit)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            coverView

            VStack(alignment: .leading, spacing: 11) {
                lockScreenHeader
                progressSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 14)
        .padding(.vertical, 14)
        .padding(.trailing, 10)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            readingAccentColor.opacity(0.16),
                            readingAccentColor.opacity(0.06),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var lockScreenHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(attrs.bookTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(attrs.bookAuthor)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            lockScreenTimer
                .padding(.trailing, lockScreenTimerTrailingInset)
        }
    }

    private var lockScreenTimer: some View {
        Group {
            if let target = state.targetSeconds {
                Text(timerInterval: state.startedAt ... state.startedAt.addingTimeInterval(target),
                     pauseTime: nil,
                     countsDown: true,
                     showsHours: false)
            } else {
                Text(timerInterval: state.startedAt ... Date.distantFuture,
                     pauseTime: nil,
                     countsDown: false,
                     showsHours: false)
            }
        }
        .font(.system(size: 27, weight: .heavy, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(readingAccentColor)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .frame(width: lockScreenTimerWidth, alignment: .trailing)
        .clipped()
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(readingProgressText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 8)

                Text("\(displayedProgressPercent)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isTimedMode ? readingAccentColor : .secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            ProgressView(value: displayedProgress)
                .progressViewStyle(.linear)
                .tint(isTimedMode ? readingAccentColor : .secondary.opacity(0.45))
                .scaleEffect(x: 1, y: 1.2, anchor: .center)
        }
    }

    @ViewBuilder
    private var coverView: some View {
        Group {
            if let coverData = state.coverData,
               let uiImage = UIImage(data: coverData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    readingAccentColor.opacity(0.28),
                                    readingAccentColor.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(readingAccentColor)
                }
            }
        }
        .frame(width: 54, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Live Activity Configuration

struct ReadingTimerLiveActivity: Widget {

    // MARK: - Expanded Island Layout Constants

    private let expandedContentInset: CGFloat = 8
    private let expandedTimerTrailingInset: CGFloat = 4
    private let expandedTopInset: CGFloat = 8
    private let expandedTopHeight: CGFloat = 52
    private let expandedTimerWidth: CGFloat = 70
    private let expandedBottomSpacing: CGFloat = 6

    // MARK: - Compact Island Layout Constants

    private let compactLeadingWidth: CGFloat = 24
    private let compactTimerWidth: CGFloat = 54
    private let compactTimerTrailingInset: CGFloat = -1
    private let compactTimerFontSize: CGFloat = 18.5

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingTimerAttributes.self) { context in
            ReadingTimerLiveActivityView(context: context)
                .activityBackgroundTint(Color(.secondarySystemBackground).opacity(0.92))
                .activitySystemActionForegroundColor(readingAccentColor)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context)
                }

            } compactLeading: {
                compactLeading(context)

            } compactTrailing: {
                compactTrailing(context)

            } minimal: {
                minimalView
            }
            .keylineTint(readingAccentColor)
        }
    }

    // MARK: - Dynamic Island Expanded

    private func expandedLeading(_ context: ActivityViewContext<ReadingTimerAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(context.attributes.bookTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(context.attributes.bookAuthor)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.leading, expandedContentInset)
        .padding(.top, expandedTopInset)
        .frame(height: expandedTopHeight, alignment: .center)
    }

    private func expandedTrailing(_ context: ActivityViewContext<ReadingTimerAttributes>) -> some View {
        expandedMainTimer(context)
            .padding(.trailing, expandedTimerTrailingInset)
            .padding(.top, expandedTopInset)
            .frame(height: expandedTopHeight, alignment: .center)
    }

    @ViewBuilder
    private func expandedMainTimer(_ context: ActivityViewContext<ReadingTimerAttributes>) -> some View {
        if let target = context.state.targetSeconds {
            Text(timerInterval: context.state.startedAt ... context.state.startedAt.addingTimeInterval(target),
                 pauseTime: nil,
                 countsDown: true,
                 showsHours: false)
                .font(.system(size: 27, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(readingAccentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: expandedTimerWidth, alignment: .trailing)
                .clipped()
        } else {
            Text(timerInterval: context.state.startedAt ... Date.distantFuture,
                 pauseTime: nil,
                 countsDown: false,
                 showsHours: false)
                .font(.system(size: 27, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(readingAccentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: expandedTimerWidth, alignment: .trailing)
                .clipped()
        }
    }

    private func expandedBottom(_ context: ActivityViewContext<ReadingTimerAttributes>) -> some View {
        let isTimedMode = context.state.targetSeconds != nil
        let readingProgress = readingProgress(for: context.state)
        let timerProgress = timerProgress(for: context.state)
        let displayedProgress = isTimedMode ? timerProgress : readingProgress
        let displayedPercent = Int(displayedProgress * 100)

        return VStack(alignment: .leading, spacing: expandedBottomSpacing) {
            HStack(alignment: .center, spacing: 8) {
                Text(readingProgressText(for: context.state))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 8)

                Text("\(displayedPercent)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isTimedMode ? readingAccentColor : .secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            ProgressView(value: displayedProgress)
                .progressViewStyle(.linear)
                .tint(isTimedMode ? readingAccentColor : .secondary.opacity(0.45))
                .scaleEffect(x: 1, y: 1.12, anchor: .center)
        }
        .padding(.horizontal, expandedContentInset)
        .padding(.top, 2)
        .padding(.bottom, 1)
    }

    // MARK: - Dynamic Island Compact / Minimal

    private func compactLeading(_ context: ActivityViewContext<ReadingTimerAttributes>) -> some View {
        Image(systemName: "book.closed.fill")
            .font(.system(size: 14.5, weight: .semibold))
            .foregroundStyle(readingAccentColor)
            .frame(width: compactLeadingWidth, height: 22, alignment: .center)
    }

    private func compactTrailing(_ context: ActivityViewContext<ReadingTimerAttributes>) -> some View {
        compactTimer(context)
            .padding(.trailing, compactTimerTrailingInset)
    }

    @ViewBuilder
    private func compactTimer(_ context: ActivityViewContext<ReadingTimerAttributes>) -> some View {
        if let target = context.state.targetSeconds {
            Text(timerInterval: context.state.startedAt ... context.state.startedAt.addingTimeInterval(target),
                 pauseTime: nil,
                 countsDown: true,
                 showsHours: false)
                .font(.system(size: compactTimerFontSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(readingAccentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: compactTimerWidth, height: 22, alignment: .trailing)
                .clipped()
        } else {
            Text(timerInterval: context.state.startedAt ... Date.distantFuture,
                 pauseTime: nil,
                 countsDown: false,
                 showsHours: false)
                .font(.system(size: compactTimerFontSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(readingAccentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: compactTimerWidth, height: 22, alignment: .trailing)
                .clipped()
        }
    }

    private var minimalView: some View {
        Image(systemName: "book.closed.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(readingAccentColor)
            .frame(width: 22, height: 22, alignment: .center)
    }

    // MARK: - Shared Helpers

    private func readingProgress(for state: ReadingTimerAttributes.ContentState) -> Double {
        guard state.totalAmount > 0 else { return 0 }
        return min(max(state.progressAmount / state.totalAmount, 0), 1)
    }

    private func timerProgress(for state: ReadingTimerAttributes.ContentState) -> Double {
        guard let target = state.targetSeconds, target > 0 else {
            return readingProgress(for: state)
        }

        return min(max(state.elapsedSeconds / target, 0), 1)
    }

    private func readingProgressText(for state: ReadingTimerAttributes.ContentState) -> String {
        "\(Int(state.progressAmount)) / \(Int(state.totalAmount)) \(state.progressUnit)"
    }
}

// MARK: - Previews

#if DEBUG
private let previewAttributes = ReadingTimerAttributes(
    bookTitle: "三体",
    bookAuthor: "刘慈欣"
)

private let previewStateTimed = ReadingTimerAttributes.ContentState(
    startedAt: Date().addingTimeInterval(-10 * 60),
    targetSeconds: 25 * 60,
    elapsedSeconds: 10 * 60,
    dailyTargetMinutes: 30,
    todayTotalSeconds: 45 * 60,
    progressAmount: 156,
    progressUnit: "页",
    totalAmount: 300,
    coverData: nil
)

private let previewStateFree = ReadingTimerAttributes.ContentState(
    startedAt: Date().addingTimeInterval(-15 * 60),
    targetSeconds: nil,
    elapsedSeconds: 15 * 60,
    dailyTargetMinutes: 30,
    todayTotalSeconds: 30 * 60,
    progressAmount: 80,
    progressUnit: "页",
    totalAmount: 300,
    coverData: nil
)

#Preview("灵动岛 · 展开", as: .dynamicIsland(.expanded), using: previewAttributes) {
    ReadingTimerLiveActivity()
} contentStates: {
    previewStateTimed
    previewStateFree
}

#Preview("灵动岛 · 紧凑", as: .dynamicIsland(.compact), using: previewAttributes) {
    ReadingTimerLiveActivity()
} contentStates: {
    previewStateTimed
    previewStateFree
}

#Preview("灵动岛 · 最小化", as: .dynamicIsland(.minimal), using: previewAttributes) {
    ReadingTimerLiveActivity()
} contentStates: {
    previewStateTimed
    previewStateFree
}

#Preview("锁屏实时活动", as: .content, using: previewAttributes) {
    ReadingTimerLiveActivity()
} contentStates: {
    previewStateTimed
    previewStateFree
}
#endif
#endif
