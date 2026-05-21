#if os(macOS)
import SwiftUI

// MARK: - 📚 待读列车书架

struct QueueBookshelf: View {
    let displayBooks: [Book] // 直接接收真正的 Book 实体
    var onBookTap: (Book) -> Void // 暴露点击回调
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                Text("想读焦点").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "sparkles.rectangle.stack").foregroundColor(.orange)
            }
            
            if displayBooks.isEmpty {
                VStack(spacing: AppSpacing.xs) {
                    Image(systemName: "books.vertical").font(.system(size: 24)).foregroundColor(.secondary.opacity(0.4))
                    Text("暂无想读计划").font(.system(size: 13, weight: .medium)).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                HStack(alignment: .top, spacing: AppSpacing.l) {
                    ForEach(displayBooks) { book in
                        PlannedBookItem(book: book)
                            .frame(width: 100)
                            .frame(maxWidth: .infinity)
                            .onTapGesture { onBookTap(book) } // 触发闭包
                    }
                    if displayBooks.count < 4 {
                        ForEach(0..<(4 - displayBooks.count), id: \.self) { _ in Spacer().frame(maxWidth: .infinity) }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center).padding(.top, 8)
            }
        }
        .padding(AppSpacing.xl).glassEffect(in: .rect(cornerRadius: AppRadius.panel))
    }
}

private struct PlannedBookItem: View {
    let book: Book
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                .frame(width: 100, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
                .shadow(color: Color.black.opacity(isHovered ? 0.2 : 0.1), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.bookCover).stroke(Color.primary.opacity(0.05), lineWidth: 0.5))
                .scaleEffect(isHovered ? 1.05 : 1.0).animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        }
        .contentShape(Rectangle())
        .onHover { h in isHovered = h; if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
    }
}

#Preview("待读列车") {
    QueueBookshelf(displayBooks: [], onBookTap: { _ in })
        .padding().frame(width: 600, height: 300)
}
#endif
