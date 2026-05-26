#if os(macOS) || os(iOS)
import SwiftUI

private struct ExcerptWallHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ExcerptWallCardContent: View {
    let excerpt: ExcerptListItem
    @Binding var naturalHeight: CGFloat
    var maxHeight: CGFloat = 700
    var ellipsisBottomPadding: CGFloat = AppSpacing.l
    let onOpenFullscreen: () -> Void

    private var isTruncated: Bool { naturalHeight > maxHeight }

    var body: some View {
        AppCard {
            ZStack(alignment: .bottom) {
                ExcerptWallTextLayout(excerpt: excerpt)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(key: ExcerptWallHeightPreferenceKey.self, value: geometry.size.height)
                        }
                    )
                    .frame(height: isTruncated ? maxHeight : nil, alignment: .top)
                    .mask {
                        if isTruncated {
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .black, location: 0.75),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        } else {
                            Color.black
                        }
                    }
                    .clipped()

                if isTruncated {
                    Button(action: onOpenFullscreen) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 44, height: 28)
                            .foregroundColor(.white)
                            .appCapsuleStyle(tint: excerpt.category.themeColor, fillOpacity: 0.90)
                    }
                    .buttonStyle(.plain)
                    #if os(macOS)
                    .help("全屏阅读")
                    #endif
                    .padding(.bottom, ellipsisBottomPadding)
                }
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topTrailing) {
                AppCapsuleLabel(text: excerpt.category.displayName, tint: excerpt.category.themeColor)
            }
            .onPreferenceChange(ExcerptWallHeightPreferenceKey.self) { height in
                if abs(naturalHeight - height) > 1 {
                    naturalHeight = height
                }
            }
        }
    }
}

private struct ExcerptWallTextLayout: View {
    let excerpt: ExcerptListItem

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if [.poetry, .lyric, .prose].contains(excerpt.category) {
                titleAndAuthor
            }

            switch excerpt.category {
            case .poetry:
                bodyText(excerpt.content, alignment: .center, textAlignment: .center)
            case .lyric, .prose:
                bodyText(indentedContent, alignment: .leading, textAlignment: .leading)
            case .quote:
                bodyText(excerpt.content, alignment: .leading, textAlignment: .leading)
                    .padding(.bottom, 24)
                sourceLine("—— \(excerpt.sourceAuthorDisplay)")
            case .movie:
                bodyText(excerpt.content, alignment: .leading, textAlignment: .leading)
                    .padding(.bottom, 24)
                sourceLine("—— \(excerpt.sourceAuthorDisplay)（\(excerpt.sourceTitleDisplay)）")
            case .web:
                bodyText(excerpt.content, alignment: .leading, textAlignment: .leading)
            case .bookExcerpt, .note:
                bodyText(excerpt.content, alignment: .leading, textAlignment: .leading)
                    .padding(.bottom, 24)
                if excerpt.isBookBound {
                    sourceLine("《\(excerpt.bookDisplayTitle)》")
                }
            }
        }
    }

    private func bodyText(_ text: String, alignment: Alignment, textAlignment: TextAlignment) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .regular, design: .serif))
            .lineSpacing(14)
            .foregroundColor(.primary.opacity(0.85))
            .multilineTextAlignment(textAlignment)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func sourceLine(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundColor(.secondary)
        }
    }

    private var titleAndAuthor: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Spacer()
            Text(excerpt.sourceTitleDisplay)
                .font(.system(size: 28, weight: .heavy, design: .serif))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            Text("")
                .frame(width: 0)
                .overlay(alignment: .bottomLeading) {
                    if excerpt.sourceAuthorDisplay != "佚名" {
                        Text(excerpt.sourceAuthorDisplay)
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(.secondary)
                            .fixedSize()
                            .offset(x: 20, y: -2)
                    }
                }
            Spacer()
        }
        .padding(.bottom, 20)
    }

    private var indentedContent: String {
        excerpt.content
            .components(separatedBy: .newlines)
            .map { "\u{3000}\u{3000}" + $0 }
            .joined(separator: "\n")
    }
}
#endif
