import SwiftUI
import UIKit

enum AppTheme {
    static let accent = Color(red: 0.68, green: 0.46, blue: 0.23)
    static let accentSoft = Color(red: 0.86, green: 0.73, blue: 0.55)
    static let ink = Color(red: 0.13, green: 0.12, blue: 0.10)
    static let muted = Color(red: 0.50, green: 0.47, blue: 0.42)

    static let pageHorizontalPadding: CGFloat = 20
    static let cardRadius: CGFloat = 24
    static let controlRadius: CGFloat = 16
    static let contentSpacing: CGFloat = 18
    static let bookCoverAspectRatio: CGFloat = 2.0 / 3.0

    static let contentAnimation = Animation.smooth(duration: 0.24)
    static let controlAnimation = Animation.snappy(duration: 0.18)

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.06, green: 0.06, blue: 0.065)
            : Color(red: 0.96, green: 0.945, blue: 0.915)
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.125, green: 0.123, blue: 0.128)
            : Color(red: 1.00, green: 0.995, blue: 0.975)
    }

    static func insetSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.17, green: 0.165, blue: 0.17)
            : Color(red: 0.94, green: 0.925, blue: 0.895)
    }

    static func stroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.085)
            : Color.black.opacity(0.065)
    }

    static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.54)
    }

    static func tertiaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.38) : Color.black.opacity(0.34)
    }
}

struct AppCard<Content: View>: View {
    var padding: CGFloat = 18
    var radius: CGFloat = AppTheme.cardRadius
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface(colorScheme), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppTheme.stroke(colorScheme), lineWidth: 1)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.055), radius: colorScheme == .dark ? 14 : 12, y: 6)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 21, weight: .semibold))
            Spacer()
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct MetricValue: View {
    let value: Int
    let label: String
    var valueSize: CGFloat = 34
    var labelSize: CGFloat = 13
    var spacing: CGFloat = 5

    var body: some View {
        VStack(alignment: .center, spacing: spacing) {
            Text("\(value)")
                .font(.system(size: valueSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: labelSize, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

enum AppEmptyStateStyle: Equatable {
    case page
    case compact

    var iconSize: CGFloat {
        switch self {
        case .page: 30
        case .compact: 22
        }
    }

    var iconContainerSize: CGFloat {
        switch self {
        case .page: 58
        case .compact: 44
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .page: 92
        case .compact: 26
        }
    }
}

struct AppEmptyState: View {
    let title: String
    var message: String?
    var systemImage: String = "books.vertical"
    var style: AppEmptyStateStyle = .page

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: style.iconSize, weight: .medium))
                .foregroundStyle(AppTheme.accent.opacity(colorScheme == .dark ? 0.72 : 0.66))
                .frame(width: style.iconContainerSize, height: style.iconContainerSize)
                .background(AppTheme.accent.opacity(colorScheme == .dark ? 0.12 : 0.10), in: Circle())
                .overlay {
                    Circle()
                        .stroke(AppTheme.accent.opacity(colorScheme == .dark ? 0.14 : 0.12), lineWidth: 1)
                }

            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: style == .page ? 17 : 16, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText(colorScheme))

                if let message {
                    Text(message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.tertiaryText(colorScheme))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, style.verticalPadding)
        .transition(.opacity.combined(with: .offset(y: 6)))
    }
}

struct StatusBadge: View {
    let status: BookStatus

    var body: some View {
        Text(status.title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppTheme.accent.opacity(0.12), in: Capsule())
    }
}

struct KindBadge: View {
    let kind: BookTextKind

    // 摘录和笔记同等权重，各用独立暖色
    private static let excerptColor = AppTheme.accent
    private static let noteColor = Color(red: 0.30, green: 0.55, blue: 0.48) // 暖鼠尾草绿

    private var accent: Color {
        kind == .excerpt ? Self.excerptColor : Self.noteColor
    }

    var body: some View {
        Text(kind.title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                accent.opacity(0.12),
                in: Capsule()
            )
    }
}

struct BookCover: View {
    let book: Book

    var body: some View {
        ZStack {
            if let image = BookCoverImageCache.image(for: book) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.accent.opacity(0.86),
                                Color(red: 0.27, green: 0.21, blue: 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 8) {
                    Text(book.title.isEmpty ? "未命名" : book.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                    if !book.author.isEmpty {
                        Text(book.author)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                    }
                }
                .padding(12)
            }
        }
        .aspectRatio(AppTheme.bookCoverAspectRatio, contentMode: .fit)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(.black.opacity(0.16))
                .frame(width: 5)
                .padding(.vertical, 7)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 7)
    }
}

private enum BookCoverImageCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for book: Book) -> UIImage? {
        guard let coverData = book.coverData else { return nil }
        let key = "\(book.id.uuidString)-\(coverData.count)-\(coverData.hashValue)" as NSString
        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }
        guard let image = UIImage(data: coverData) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

struct FactPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("Theme Components") {
    PreviewHost { data in
        PageShell {
            AppCard {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "组件预览", subtitle: "主题")
                    HStack(spacing: 12) {
                        StatusBadge(status: .planned)
                        StatusBadge(status: .reading)
                        KindBadge(kind: .excerpt)
                        KindBadge(kind: .note)
                    }
                    HStack(spacing: 18) {
                        FactPill(value: "146", label: "页")
                        FactPill(value: "42", label: "分钟")
                        FactPill(value: "3", label: "摘记")
                    }
                    if let book = data.books.first {
                        BookCover(book: book)
                            .frame(width: 132)
                    }
                    AppEmptyState(
                        title: "暂无内容",
                        message: "空状态只展示说明，不承载操作按钮。",
                        systemImage: "tray"
                    )
                }
            }
        }
    }
}
#endif
