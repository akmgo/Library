import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.70, green: 0.48, blue: 0.24)
    static let ink = Color(red: 0.12, green: 0.11, blue: 0.10)
    static let muted = Color(red: 0.48, green: 0.45, blue: 0.40)

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.07, green: 0.07, blue: 0.07)
            : Color(red: 0.96, green: 0.94, blue: 0.90)
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.13, green: 0.13, blue: 0.13)
            : Color(red: 1.00, green: 0.99, blue: 0.97)
    }

    static func insetSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.17, green: 0.17, blue: 0.17)
            : Color(red: 0.94, green: 0.92, blue: 0.88)
    }

    static func stroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.07)
    }
}

struct AppCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface(colorScheme), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.stroke(colorScheme), lineWidth: 1)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.26 : 0.08), radius: 18, y: 8)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
            Spacer()
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct EmptyHint: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
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

struct BookCover: View {
    let book: Book

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.accent.opacity(0.85),
                            Color(red: 0.22, green: 0.18, blue: 0.13)
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
