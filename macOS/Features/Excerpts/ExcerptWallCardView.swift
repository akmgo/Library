#if os(macOS)
import SwiftUI

struct ExcerptWallCardView: View {
    let excerpt: ExcerptListItem
    let onEdit: (ExcerptListItem) -> Void
    var allowsEditGesture: Bool = true

    @State private var naturalInkHeight: CGFloat = 0
    @State private var isInkFullscreenPresented = false

    private let inkMaxHeight: CGFloat = 700

    var body: some View {
        ExcerptWallCardContent(
            excerpt: excerpt,
            naturalHeight: $naturalInkHeight,
            maxHeight: inkMaxHeight,
            ellipsisBottomPadding: 24
        ) {
            isInkFullscreenPresented = true
        }
        .excerptDoubleTap(enabled: allowsEditGesture) {
            onEdit(excerpt)
        }
        .sheet(isPresented: $isInkFullscreenPresented) {
            InkExcerptFullscreenView(excerpt: excerpt) {
                isInkFullscreenPresented = false
            }
            .frame(minWidth: 760, minHeight: 680)
        }
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
    @Environment(\.colorScheme) private var colorScheme

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
                .fill(AppColors.primaryBackground(for: colorScheme))
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 40) {
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
