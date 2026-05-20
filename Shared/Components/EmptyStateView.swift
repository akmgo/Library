#if os(macOS) || os(iOS)
import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var message: String?

    var body: some View {
        VStack(spacing: AppSpacing.s) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .regular))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.emptyState)
    }
}
#endif
