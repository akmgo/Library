#if os(macOS) || os(iOS)
import SwiftUI

struct GlassCardModifier: ViewModifier {
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
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

struct ReadingRecordCardStyleModifier: ViewModifier {
    let cornerRadius: CGFloat
    let backgroundOpacity: Double
    let strokeOpacity: Double

    @Environment(\.colorScheme) private var colorScheme

    init(
        cornerRadius: CGFloat = AppRadius.card,
        backgroundOpacity: Double = 0.8,
        strokeOpacity: Double = 0.05
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
    func readingRecordCardStyle(
        cornerRadius: CGFloat = AppRadius.card,
        backgroundOpacity: Double = 0.8,
        strokeOpacity: Double = 0.05
    ) -> some View {
        modifier(
            ReadingRecordCardStyleModifier(
                cornerRadius: cornerRadius,
                backgroundOpacity: backgroundOpacity,
                strokeOpacity: strokeOpacity
            )
        )
    }
}
#endif
