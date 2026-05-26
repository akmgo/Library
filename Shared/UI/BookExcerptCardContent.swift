#if os(macOS) || os(iOS)
import SwiftUI

struct BookExcerptCardContent: View {
    let item: ReadingStatsCalculator.BookExcerptItemSnapshot
    var contentFontSize: CGFloat = 16
    var showsHeader = true

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            if showsHeader {
                header
            }

            Text(verbatim: item.content)
                .font(contentFont)
                .foregroundColor(.primary)
                .lineSpacing(item.isNote ? 6 : 8)
                .fixedSize(horizontal: false, vertical: true)
                #if os(macOS)
                .textSelection(.enabled)
                #endif
        }
    }

    private var header: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: item.isNote ? "pencil.line" : "text.quote")
                .foregroundColor(item.isNote ? .purple : .indigo)
            Text(item.isNote ? "阅读笔记" : "精彩摘录")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
            Text(item.dateText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary.opacity(0.6))
        }
    }

    private var contentFont: Font {
        if item.isNote {
            return .system(size: contentFontSize)
        }
        return .system(size: contentFontSize, weight: .regular, design: .serif)
    }
}
#endif
