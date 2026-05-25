#if os(macOS) || os(iOS)
import SwiftUI

enum AppCardStyleMetrics {
    static let cardBackgroundOpacity: Double = 0.8
    static let cardStrokeOpacity: Double = 0.05
    static let innerBackgroundOpacity: Double = 0.72
    static let innerStrokeOpacity: Double = 0.05
}

struct AppGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 16) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(in: .rect(cornerRadius: cornerRadius))
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(AppGlassCardModifier(cornerRadius: cornerRadius))
    }
}

struct AppCardStyleModifier: ViewModifier {
    let cornerRadius: CGFloat
    let backgroundOpacity: Double
    let strokeOpacity: Double

    @Environment(\.colorScheme) private var colorScheme

    init(
        cornerRadius: CGFloat = AppRadius.card,
        backgroundOpacity: Double = AppCardStyleMetrics.cardBackgroundOpacity,
        strokeOpacity: Double = AppCardStyleMetrics.cardStrokeOpacity
    ) {
        self.cornerRadius = cornerRadius
        self.backgroundOpacity = backgroundOpacity
        self.strokeOpacity = strokeOpacity
    }

    func body(content: Content) -> some View {
        content
            .background(
                AppColors.secondaryBackground(for: colorScheme)
                    .opacity(backgroundOpacity)
                    .background(AppMaterials.card)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(strokeOpacity), lineWidth: 1)
            )
    }
}

extension View {
    func appCardStyle(
        cornerRadius: CGFloat = AppRadius.card,
        backgroundOpacity: Double = AppCardStyleMetrics.cardBackgroundOpacity,
        strokeOpacity: Double = AppCardStyleMetrics.cardStrokeOpacity
    ) -> some View {
        modifier(
            AppCardStyleModifier(
                cornerRadius: cornerRadius,
                backgroundOpacity: backgroundOpacity,
                strokeOpacity: strokeOpacity
            )
        )
    }

    func appInnerCardStyle(
        cornerRadius: CGFloat = AppRadius.m,
        backgroundOpacity: Double = AppCardStyleMetrics.innerBackgroundOpacity,
        strokeOpacity: Double = AppCardStyleMetrics.innerStrokeOpacity
    ) -> some View {
        appCardStyle(
            cornerRadius: cornerRadius,
            backgroundOpacity: backgroundOpacity,
            strokeOpacity: strokeOpacity
        )
    }

    func readingRecordCardStyle(
        cornerRadius: CGFloat = AppRadius.card,
        backgroundOpacity: Double = AppCardStyleMetrics.cardBackgroundOpacity,
        strokeOpacity: Double = AppCardStyleMetrics.cardStrokeOpacity
    ) -> some View {
        appCardStyle(
            cornerRadius: cornerRadius,
            backgroundOpacity: backgroundOpacity,
            strokeOpacity: strokeOpacity
        )
    }
}
#endif
