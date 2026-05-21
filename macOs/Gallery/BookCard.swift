#if os(macOS)
import SwiftData
import SwiftUI

// MARK: - 🎬 响应全局洗牌调度的轻量卡片包装

struct AnimatedCardGlide: View {
    let book: Book
    let activeTab: String
    
    let isBatchEditMode: Bool
    let gridScale: GalleryGridScale
    
    @Binding var selectedBooksForBatch: Set<String>
    @Binding var selectedBook: Book?
    
    var body: some View {
        BookCard(
            book: book, activeTab: activeTab, gridScale: gridScale,
            isBatchEditMode: isBatchEditMode,
            selectedBooksForBatch: $selectedBooksForBatch,
            selectedBook: $selectedBook
        )
    }
}

// MARK: - 📘 核心封面与信息渲染组件

struct BookCard: View {
    let book: Book
    let activeTab: String
    let gridScale: GalleryGridScale
    let isBatchEditMode: Bool
    
    @Binding var selectedBooksForBatch: Set<String>
    @Binding var selectedBook: Book?
    
    @State private var isHovered = false
    
    var body: some View {
        let isSelected = selectedBooksForBatch.contains(book.id)
        
        VStack(spacing: 0) {
            BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                .aspectRatio(2 / 3, contentMode: .fill)
                .frame(width: gridScale.width, height: gridScale.width * 1.5)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous).stroke(isSelected ? AppColors.selection : Color.clear, lineWidth: 3).padding(-2))
                .overlay(alignment: .topTrailing) {
                    if isBatchEditMode {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22 * gridScale.uiScale))
                            .foregroundColor(isSelected ? .blue : .white)
                            .shadow(color: .black.opacity(0.2), radius: 2)
                            .padding(10 * gridScale.uiScale)
                    }
                }
                .shadow(color: Color.black.opacity(isHovered ? 0.2 : 0.08), radius: isHovered ? 12 : 4, y: isHovered ? 6 : 2)
                .scaleEffect(isHovered ? 1.03 : 1.0)
                .offset(y: isHovered ? -4 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
                .onTapGesture {
                    if isBatchEditMode {
                        let id = book.id
                        if isSelected { selectedBooksForBatch.remove(id) } else { selectedBooksForBatch.insert(id) }
                    } else {
                        withAnimation(.appFluidSpring) { selectedBook = book }
                    }
                }
                .onHover { h in
                    if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
        }
        .frame(width: gridScale.width)
        .contentShape(Rectangle())
        .onHover { h in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { isHovered = h }
        }
    }
}
#endif
