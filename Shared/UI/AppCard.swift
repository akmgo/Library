#if os(macOS) || os(iOS)
import SwiftUI

/// Unified primary card container with consistent internal spacing.
/// All cards across macOS and iOS use this component for identical
/// padding, frame, and surface styling everywhere.
///
/// Default corner radius is `AppRadius.panel` (26).
struct AppCard<Content: View>: View {
    let cornerRadius: CGFloat
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        cornerRadius: CGFloat = AppRadius.panel,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: cardShadowColor, radius: cardShadowRadius, y: cardShadowY)
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 26 / 255, green: 26 / 255, blue: 29 / 255)
            : Color.white
    }

    private var cardStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.07)
            : Color.black.opacity(0.035)
    }

    private var cardShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.36)
            : Color.black.opacity(0.04)
    }

    private var cardShadowRadius: CGFloat {
        colorScheme == .dark ? 28 : 14
    }

    private var cardShadowY: CGFloat {
        colorScheme == .dark ? 12 : 6
    }
}
#endif
