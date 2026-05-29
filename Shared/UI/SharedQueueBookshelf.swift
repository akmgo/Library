#if os(macOS) || os(iOS)
import SwiftUI

// MARK: - 想读焦点（共享）

/// 横向排列的书籍封面组，内部元素自适应撑满空间，无固定尺寸。
/// 调用方通过 `.frame()` 控制最终宽高。
/// 最多展示 4 本，不足时空位由 Spacer 填充。
struct SharedQueueBookshelf: View {
    let displayBooks: [Book]
    var onBookTap: (Book) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack {
                    Text("想读焦点")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "sparkles.rectangle.stack")
                        .foregroundColor(.orange)
                }

                if displayBooks.isEmpty {
                    Text("暂无想读计划")
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    HStack(alignment: .top, spacing: AppSpacing.l) {
                        ForEach(displayBooks.prefix(4)) { book in
                            PlannedBookItem(book: book)
                                .frame(maxWidth: .infinity)
                                .onTapGesture { onBookTap(book) }
                        }
                        if displayBooks.count < 4 {
                            ForEach(0..<(4 - displayBooks.count), id: \.self) { _ in
                                Spacer().frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                    .padding(.top, 8)
                }
            }
        }
    }
}

// MARK: - 子组件

private struct PlannedBookItem: View {
    let book: Book

    var body: some View {
        BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
            .aspectRatio(2 / 3, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
            .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.bookCover)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
            )
    }
}

#if DEBUG
#Preview("想读焦点 · 有数据") {
    SharedQueueBookshelf(displayBooks: [], onBookTap: { _ in })
        .frame(height: 220)
        .padding()
}

#Preview("想读焦点 · 空状态") {
    SharedQueueBookshelf(displayBooks: [], onBookTap: { _ in })
        .frame(height: 220)
        .padding()
}
#endif
#endif
