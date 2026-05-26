#if os(macOS) || os(iOS)
import SwiftUI

struct ReadingSemiCircleArc: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let clampedProgress = min(max(progress, 0), 1)

        let center = CGPoint(
            x: rect.midX,
            y: rect.maxY - 10
        )

        let radius = min(rect.width * 0.48, rect.height * 0.92)

        let startAngle = Angle.degrees(180)
        let endAngle = Angle.degrees(180 + 180 * clampedProgress)

        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        return path
    }
}
#endif
