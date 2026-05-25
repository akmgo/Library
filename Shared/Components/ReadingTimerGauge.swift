#if os(macOS) || os(iOS)
import SwiftUI

struct ReadingTimerGauge: View {
    let todayTotalSeconds: TimeInterval
    let dailyTargetMinutes: Int
    let elapsedSeconds: TimeInterval
    let timedTargetSeconds: TimeInterval?
    let isTiming: Bool

    private var isTimedMode: Bool { timedTargetSeconds != nil }

    private var displaySeconds: TimeInterval {
        isTiming ? elapsedSeconds : todayTotalSeconds
    }

    private var targetSeconds: TimeInterval {
        if let timed = timedTargetSeconds {
            return max(timed, 1)
        }
        return max(TimeInterval(dailyTargetMinutes * 60), 1)
    }

    private var progress: Double {
        min(max(displaySeconds / targetSeconds, 0), 1)
    }

    private var minutesText: String {
        let total = Int(displaySeconds)
        let minutes = total / 60
        return String(format: "%02d", minutes)
    }

    private var secondsText: String {
        let total = Int(displaySeconds)
        let seconds = total % 60
        return String(format: "%02d", seconds)
    }

    var body: some View {
        ZStack {
            ReadingSemiCircleArc(progress: 1)
                .stroke(
                    Color.primary.opacity(0.075),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )

            ReadingSemiCircleArc(progress: progress)
                .stroke(
                    LinearGradient(
                        colors: [
                            AppColors.readingAmber.opacity(0.68),
                            AppColors.readingAmber
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .shadow(
                    color: AppColors.readingAmber.opacity(isTiming ? 0.16 : 0.06),
                    radius: 8,
                    y: 4
                )
                .animation(.easeInOut(duration: 0.35), value: progress)

            VStack(spacing: 4) {
                HStack(alignment: .center, spacing: 4) {
                    Text(minutesText)
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 58, height: 48, alignment: .center)

                    Text(":")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.readingAmber.opacity(0.82))
                        .frame(width: 14, height: 48, alignment: .center)
                        .offset(y: -3)

                    Text(secondsText)
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 58, height: 48, alignment: .center)
                }
                .foregroundStyle(.primary.opacity(0.9))
                .contentTransition(.numericText())

                Text(isTimedMode ? "定时 \(Int((timedTargetSeconds ?? 0) / 60)) 分钟" : "今日目标 \(dailyTargetMinutes) 分钟")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.62))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.10))
                    )
            }
            .offset(y: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
