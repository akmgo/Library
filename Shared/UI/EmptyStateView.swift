#if os(macOS) || os(iOS)
import SwiftUI

struct EmptyStateView: View {
    let title: String
    var message: String?
    var minHeight: CGFloat? = 360

    init(
        systemImage: String = "",
        title: String,
        message: String? = nil,
        iconSize _: CGFloat = 42,
        minHeight: CGFloat? = 360
    ) {
        self.title = title
        self.message = message
        self.minHeight = minHeight
    }

    var body: some View {
        VStack(spacing: AppSpacing.s) {
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
