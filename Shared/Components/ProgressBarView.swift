#if os(macOS) || os(iOS)
import SwiftUI

struct ProgressBarView: View {
    let progress: Double
    var tint: Color = AppColors.readingAmber
    var height: CGFloat = 8
    var trackOpacity: Double = 0.08
    var fillOpacity: Double = 1
    var animated: Bool = true

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(trackOpacity))
                Capsule()
                    .fill(tint.opacity(fillOpacity))
                    .frame(width: geometry.size.width * clampedProgress)
                    .animation(animated ? .easeOut(duration: 0.18) : nil, value: clampedProgress)
            }
        }
        .frame(height: height)
    }
}
#endif
