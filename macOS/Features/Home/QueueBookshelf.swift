#if os(macOS)
import SwiftUI

// MARK: - 📚 待读列车书架

struct QueueBookshelf: View {
    let displayBooks: [Book] // 直接接收真正的 Book 实体
    var onBookTap: (Book) -> Void // 暴露点击回调
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                Text("想读焦点").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "sparkles.rectangle.stack").foregroundColor(.orange)
            }
            
            if displayBooks.isEmpty {
                Text("暂无想读计划")
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
        }
    }
}

private struct PlannedBookItem: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                .frame(width: 100, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
                .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.bookCover).stroke(Color.primary.opacity(0.05), lineWidth: 0.5))
        }
        .contentShape(Rectangle())
    }
}

#Preview("待读列车") {
    QueueBookshelf(displayBooks: [], onBookTap: { _ in })
        .padding().frame(width: 600, height: 300)
}
#endif
