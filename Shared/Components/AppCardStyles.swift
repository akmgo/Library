#if os(macOS) || os(iOS)
import SwiftUI

struct AppCapsuleLabel: View {
    let text: String
    let tint: Color
    var fontSize: CGFloat = 11
    var fontWeight: Font.Weight = .bold
    var horizontalPadding: CGFloat = 10
    var verticalPadding: CGFloat = 4
    var fillOpacity: Double = 0.15
    var strokeOpacity: Double = 0

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: fontWeight, design: .rounded))
            .foregroundColor(tint)
            .lineLimit(1)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .appCapsuleStyle(tint: tint, fillOpacity: fillOpacity, strokeOpacity: strokeOpacity)
    }
}

struct AppCapsuleModifier: ViewModifier {
    let tint: Color
    let fillOpacity: Double
    let strokeOpacity: Double

    func body(content: Content) -> some View {
        content
            .background(Capsule(style: .continuous).fill(tint.opacity(fillOpacity)))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(strokeOpacity), lineWidth: strokeOpacity > 0 ? 1 : 0)
            )
    }
}

struct AppInnerBlockModifier: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    init(cornerRadius: CGFloat = AppRadius.m) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background(
                AppColors.innerBlock(for: colorScheme),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.innerStroke(for: colorScheme), lineWidth: 1)
            )
    }
}

struct AppInnerCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .appCapsuleStyle(tint: .secondary, fillOpacity: 0.10, strokeOpacity: 0.08)
    }
}

extension View {
    func appCapsuleStyle(tint: Color, fillOpacity: Double = 0.15, strokeOpacity: Double = 0) -> some View {
        modifier(AppCapsuleModifier(tint: tint, fillOpacity: fillOpacity, strokeOpacity: strokeOpacity))
    }

    func appInnerBlockStyle(cornerRadius: CGFloat = AppRadius.m) -> some View {
        modifier(AppInnerBlockModifier(cornerRadius: cornerRadius))
    }

    func appInnerCapsuleStyle() -> some View {
        modifier(AppInnerCapsuleModifier())
    }
}
#endif
