#if os(macOS) || os(iOS)
import SwiftUI

struct ProgressBarView: View {
    let progress: Double
    var tint: Color = AppColors.readingAmber

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(AppComponentSizes.Progress.linearTrackOpacity))
                Capsule()
                    .fill(tint)
                    .frame(width: geometry.size.width * clampedProgress)
            }
        }
        .frame(height: AppComponentSizes.Progress.linearHeight)
    }
}
#endif
