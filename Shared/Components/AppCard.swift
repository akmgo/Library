#if os(macOS) || os(iOS)
import SwiftUI

/// Unified primary card container with consistent internal spacing and native
/// `glassEffect` surface. All primary cards across macOS and iOS use this component
/// so that padding, frame, and glass material are identical everywhere.
///
/// Default corner radius is `AppRadius.panel` (28) matching the macOS home card
/// standard. Set `usesClearMaterial: true` for the translucent clear-glass variant.
struct AppCard<Content: View>: View {
    let cornerRadius: CGFloat
    let usesClearMaterial: Bool
    @ViewBuilder let content: () -> Content

    init(
        cornerRadius: CGFloat = AppRadius.panel,
        usesClearMaterial: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.usesClearMaterial = usesClearMaterial
        self.content = content
    }

    var body: some View {
        content()
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(usesClearMaterial ? .clear : .regular, in: .rect(cornerRadius: cornerRadius))
    }
}
#endif
