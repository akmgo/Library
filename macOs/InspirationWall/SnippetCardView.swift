#if os(macOS)
import SwiftUI

private struct InkExcerptHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ExcerptWallCardView: View {
    let excerpt: ExcerptListItem
    let onEdit: (ExcerptListItem) -> Void
    var allowsEditGesture: Bool = true

    @State private var naturalInkHeight: CGFloat = 0
    @State private var isInkFullscreenPresented = false

    private let inkMaxHeight: CGFloat = 700
    private var isInkTruncated: Bool { naturalInkHeight > inkMaxHeight }

    var body: some View {
        inkGalleryCard
        .sheet(isPresented: $isInkFullscreenPresented) {
            InkExcerptFullscreenView(excerpt: excerpt) {
                isInkFullscreenPresented = false
            }
            .frame(minWidth: 760, minHeight: 680)
        }
    }

    private var inkGalleryCard: some View {
        ZStack(alignment: .bottom) {
            inkTextLayout
                .padding(.horizontal, AppSpacing.xl)
                .padding(.vertical, AppSpacing.xxl)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(key: InkExcerptHeightPreferenceKey.self, value: geometry.size.height)
                    }
                )
                .frame(height: isInkTruncated ? inkMaxHeight : nil, alignment: .top)
                .mask {
                    if isInkTruncated {
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

            if isInkTruncated {
                Button {
                    isInkFullscreenPresented = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 28)
                        .foregroundColor(.white)
                        .background(excerpt.category.themeColor.opacity(0.9))
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                .help("全屏阅读")
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Text(excerpt.category.displayName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(excerpt.category.themeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(excerpt.category.themeColor.opacity(0.15))
                .clipShape(Capsule())
                .padding([.top, .trailing], 16)
        }
        .onPreferenceChange(InkExcerptHeightPreferenceKey.self) { height in
            if abs(naturalInkHeight - height) > 1 {
                naturalInkHeight = height
            }
        }
        .glassCardSurface()
        .excerptDoubleTap(enabled: allowsEditGesture) {
            onEdit(excerpt)
        }
    }

    @ViewBuilder
    private var inkTextLayout: some View {
        VStack(alignment: .center, spacing: 0) {
            if [.poetry, .lyric, .prose].contains(excerpt.category) {
                inkTitleAndAuthor
            }

            switch excerpt.category {
            case .poetry:
                Text(excerpt.content)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .lineSpacing(14)
                    .foregroundColor(.primary.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            case .lyric, .prose:
                Text(indentedContent)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .lineSpacing(14)
                    .foregroundColor(.primary.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .quote:
                Text(excerpt.content)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .lineSpacing(14)
                    .foregroundColor(.primary.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 24)
                HStack {
                    Spacer()
                    Text("—— \(excerpt.sourceAuthorDisplay)")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundColor(.secondary)
                }
            case .movie:
                Text(excerpt.content)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .lineSpacing(14)
                    .foregroundColor(.primary.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 24)
                HStack {
                    Spacer()
                    Text("—— \(excerpt.sourceAuthorDisplay)（\(excerpt.sourceTitleDisplay)）")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundColor(.secondary)
                }
            case .web:
                Text(excerpt.content)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .lineSpacing(14)
                    .foregroundColor(.primary.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .bookExcerpt, .note:
                Text(excerpt.content)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .lineSpacing(14)
                    .foregroundColor(.primary.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 24)
                if excerpt.isBookBound {
                    HStack {
                        Spacer()
                        Text("《\(excerpt.bookDisplayTitle)》")
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var inkTitleAndAuthor: some View {
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

private extension View {
    @ViewBuilder
    func excerptDoubleTap(enabled: Bool, action: @escaping () -> Void) -> some View {
        if enabled {
            self.onTapGesture(count: 2, perform: action)
        } else {
            self
        }
    }
}

private struct InkExcerptFullscreenView: View {
    let excerpt: ExcerptListItem
    let onClose: () -> Void

    private var indentedContent: String {
        excerpt.content
            .components(separatedBy: .newlines)
            .map { "\u{3000}\u{3000}" + $0 }
            .joined(separator: "\n")
    }

    private var supportingSource: String? {
        guard let source = excerpt.source?.trimmingCharacters(in: .whitespacesAndNewlines), !source.isEmpty else {
            return nil
        }
        guard source != excerpt.sourceTitleDisplay else {
            return nil
        }
        return source
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 40) {
                    header
                    content
                    attribution
                    sourceNote
                }
                .padding(.horizontal, 120)
                .padding(.bottom, 150)
                .frame(maxWidth: .infinity)
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(32)
        }
        .background(
            Button("") { onClose() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
        )
    }

    @ViewBuilder
    private var header: some View {
        if [.poetry, .lyric, .prose].contains(excerpt.category) {
            VStack(spacing: 16) {
                Text(excerpt.sourceTitleDisplay)
                    .font(.system(size: 36, weight: .heavy, design: .serif))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                if excerpt.sourceAuthorDisplay != "佚名" {
                    Text(excerpt.sourceAuthorDisplay)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 100)
        } else {
            Spacer().frame(height: 80)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch excerpt.category {
        case .poetry:
            Text(excerpt.content)
                .font(.system(size: 20, weight: .regular, design: .serif))
                .lineSpacing(18)
                .foregroundColor(.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        case .lyric, .prose:
            Text(indentedContent)
                .font(.system(size: 20, weight: .regular, design: .serif))
                .lineSpacing(18)
                .foregroundColor(.primary.opacity(0.9))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .quote, .movie, .web, .bookExcerpt, .note:
            Text(excerpt.content)
                .font(.system(size: 20, weight: .regular, design: .serif))
                .lineSpacing(18)
                .foregroundColor(.primary.opacity(0.9))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var attribution: some View {
        if excerpt.category == .quote {
            HStack {
                Spacer()
                Text("—— \(excerpt.sourceAuthorDisplay)")
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
        } else if excerpt.category == .movie {
            HStack {
                Spacer()
                Text("—— \(excerpt.sourceAuthorDisplay)（\(excerpt.sourceTitleDisplay)）")
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
        } else if [.bookExcerpt, .note].contains(excerpt.category), excerpt.isBookBound {
            HStack {
                Spacer()
                Text("《\(excerpt.bookDisplayTitle)》")
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
        }
    }

    @ViewBuilder
    private var sourceNote: some View {
        if let supportingSource {
            VStack(alignment: .leading, spacing: 16) {
                Divider()
                Text("来源 / 注释")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                Text(supportingSource)
                    .font(.system(size: 15, design: .serif))
                    .lineSpacing(10)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 60)
        }
    }
}
#endif
