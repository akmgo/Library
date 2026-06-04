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
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.07), radius: colorScheme == .dark ? 18 : 16, y: 8)
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

struct EmptyHint: View {
    let title: String
    let message: String
    var systemImage: String = "books.vertical"

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
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

    var body: some View {
        Text(kind.title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(kind == .excerpt ? AppTheme.accent : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                (kind == .excerpt ? AppTheme.accent.opacity(0.12) : Color.secondary.opacity(0.11)),
                in: Capsule()
            )
    }
}

struct BookCover: View {
    let book: Book

    var body: some View {
        ZStack {
            if let coverData = book.coverData, let image = UIImage(data: coverData) {
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
        .aspectRatio(0.68, contentMode: .fit)
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

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}
