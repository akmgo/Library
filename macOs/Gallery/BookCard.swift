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
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                .aspectRatio(2 / 3, contentMode: .fill)
                .frame(width: gridScale.width, height: gridScale.width * 1.5)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                .overlay(alignment: .topTrailing) {
                    if isBatchMode {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isSelected ? AppColors.readingAmber : Color.white.opacity(0.88))
                            .padding(8)
                            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    }
                }
                .shadow(color: Color.black.opacity(isHovered ? 0.14 : 0.08), radius: isHovered ? 8 : 4, y: isHovered ? 3 : 2)
                .scaleEffect(isHovered ? 1.012 : 1.0)
                .offset(y: isHovered ? -2 : 0)
                .animation(.appControlFeedback, value: isHovered)
                .onTapGesture {
                    if isBatchMode {
                        onToggleSelection()
                    } else {
                        selectedBook = book
                    }
                }
                .onHover { h in
                    if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
        }
        .frame(width: gridScale.width)
        .contentShape(Rectangle())
        .onHover { h in
            withAnimation(.appControlFeedback) { isHovered = h }
        }
    }
}
#endif
