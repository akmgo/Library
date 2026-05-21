#if os(macOS) || os(iOS)
import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var message: String?
    var iconSize: CGFloat = 42
    var minHeight: CGFloat? = 360

    var body: some View {
        VStack(spacing: AppSpacing.s) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .regular))
                .foregroundStyle(.secondary.opacity(0.55))
            Text(title)
                .font(AppTypography.titleSmall)
                .foregroundStyle(.secondary)
            if let message, !message.isEmpty {
                Text(message)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(minHeight: minHeight)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(AppSpacing.emptyState)
    }
}
#endif
