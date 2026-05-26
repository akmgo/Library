#if os(macOS) || os(iOS)
import SwiftUI

struct SettingsRow<Control: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var iconSize: CGFloat
    var titleSize: CGFloat
    var subtitleSize: CGFloat
    var subtitleLineLimit: Int
    @ViewBuilder let control: () -> Control

    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        iconSize: CGFloat = 28,
        titleSize: CGFloat = 13,
        subtitleSize: CGFloat = 11,
        subtitleLineLimit: Int = 1,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.iconSize = iconSize
        self.titleSize = titleSize
        self.subtitleSize = subtitleSize
        self.subtitleLineLimit = subtitleLineLimit
        self.control = control
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.s) {
            SettingsRowIcon(systemImage: icon, color: iconColor, size: iconSize)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: titleSize, weight: .bold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: subtitleSize))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .lineLimit(subtitleLineLimit)
            }

            Spacer(minLength: AppSpacing.s)

            control()
        }
        .padding(.vertical, 6)
    }
}

extension SettingsRow where Control == EmptyView {
    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        iconSize: CGFloat = 28,
        titleSize: CGFloat = 13,
        subtitleSize: CGFloat = 11,
        subtitleLineLimit: Int = 1
    ) {
        self.init(
            icon: icon,
            iconColor: iconColor,
            title: title,
            subtitle: subtitle,
            iconSize: iconSize,
            titleSize: titleSize,
            subtitleSize: subtitleSize,
            subtitleLineLimit: subtitleLineLimit,
            control: { EmptyView() }
        )
    }
}

private struct SettingsRowIcon: View {
    let systemImage: String
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: max(6, size * 0.22), style: .continuous)
                .fill(color)
                .frame(width: size, height: size)
            Image(systemName: systemImage)
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundColor(.white)
        }
    }
}
#endif
