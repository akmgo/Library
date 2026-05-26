#if os(macOS) || os(iOS)
import SwiftUI

enum ReadingSessionRowLayout {
    case regular
    case compact
}

struct ReadingSessionRowContent: View, Equatable {
    let snapshot: ReadingStatsCalculator.ReadingSessionRowSnapshot
    var layout: ReadingSessionRowLayout = .regular

    var body: some View {
        switch layout {
        case .regular:
            regularLayout
        case .compact:
            compactLayout
        }
    }

    private var regularLayout: some View {
        HStack(spacing: 20) {
            Text(snapshot.dateText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 124, alignment: .leading)

            Text(snapshot.timeRangeText)
                .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(snapshot.durationText)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.readingAmber)
                .frame(width: 80, alignment: .leading)

            if let deltaText = snapshot.deltaText {
                Text(deltaText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.readingAmber)
                    .frame(width: 64, alignment: .leading)
            } else {
                Spacer().frame(width: 64)
            }

            Spacer()

            inputModeBadge
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var compactLayout: some View {
        HStack(spacing: AppSpacing.s) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.dateText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(snapshot.timeRangeText)
                    .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(snapshot.durationText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.readingAmber)
                HStack(spacing: 6) {
                    if let deltaText = snapshot.deltaText {
                        Text(deltaText)
                    }
                    Text(snapshot.inputModeText)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.65))
            }
        }
        .padding(.horizontal, AppSpacing.s)
        .padding(.vertical, AppSpacing.s)
    }

    private var inputModeBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: snapshot.inputModeSystemImage)
                .font(.system(size: 9))
            Text(snapshot.inputModeText)
                .font(.system(size: 10, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.secondary.opacity(0.5))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .appInnerCapsuleStyle()
    }
}
#endif
