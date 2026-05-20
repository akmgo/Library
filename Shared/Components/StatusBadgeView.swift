#if os(macOS) || os(iOS)
import SwiftUI

struct StatusBadgeView: View {
    let status: BookStatus
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let statusColor = AppColors.statusColor(for: status, colorScheme: colorScheme)

        Text(status.displayName)
            .font(AppTypography.micro)
            .foregroundStyle(statusColor)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, AppSpacing.xxs)
            .background(statusColor.opacity(0.12), in: Capsule())
    }
}
#endif
