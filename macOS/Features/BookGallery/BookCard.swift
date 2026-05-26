#if os(macOS)
import SwiftData
import SwiftUI

// MARK: - 🎬 响应全局洗牌调度的轻量卡片包装

struct AnimatedCardGlide: View {
    let book: Book
    let gridScale: GalleryGridScale
    @Binding var selectedBook: Book?
    let isBatchMode: Bool
    let isSelected: Bool
    let onToggleSelection: () -> Void
    
    var body: some View {
        BookCard(
            book: book,
            gridScale: gridScale,
            selectedBook: $selectedBook,
            isBatchMode: isBatchMode,
            isSelected: isSelected,
            onToggleSelection: onToggleSelection
        )
    }
}

// MARK: - 📘 核心封面与信息渲染组件

struct BookCard: View {
    let book: Book
    let gridScale: GalleryGridScale
    @Binding var selectedBook: Book?
    let isBatchMode: Bool
    let isSelected: Bool
    let onToggleSelection: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                .aspectRatio(2 / 3, contentMode: .fill)
                .frame(width: gridScale.width, height: gridScale.width * 1.5)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous)
                        .stroke(isBatchMode && isSelected ? Color.blue : Color.clear, lineWidth: 3)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
                .onTapGesture {
                    if isBatchMode {
                        onToggleSelection()
                    } else {
                        selectedBook = book
                    }
                }
        }
        .frame(width: gridScale.width)
        .contentShape(Rectangle())
    }
}
#endif
