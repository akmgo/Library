#if os(macOS)
import SwiftUI
import SwiftData

// MARK: - 📚 待读列车书架

/// 在界面底部展现“待读列车”前四本序列的书架占位图。
struct FluidQueueBookshelfChart: View {
    let wantToReadBooks: [Book]
    
    var body: some View {
        let displayBooks = Array(wantToReadBooks.prefix(4))
        GroupBox {
            if displayBooks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "books.vertical").font(.system(size: 24)).foregroundColor(.secondary.opacity(0.4))
                    Text("暂无想读计划").font(.system(size: 13, weight: .medium)).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(displayBooks) { book in WantToReadBookItem(book: book).frame(maxWidth: .infinity) }
                    if displayBooks.count < 4 { ForEach(0..<(4 - displayBooks.count), id: \.self) { _ in Spacer().frame(maxWidth: .infinity) } }
                }
                .frame(maxHeight: .infinity, alignment: .center).padding(.top, 8)
            }
        } label: {
            HStack { Text("想读焦点").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.primary); Spacer(); Image(systemName: "sparkles.rectangle.stack").foregroundColor(.orange) }
        }
        .groupBoxStyle(NativeWidgetGroupBoxStyle())
    }
}

/// 渲染带阴影的小尺寸书籍模型
private struct WantToReadBookItem: View {
    let book: Book
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            LocalCoverView(coverData: book.coverData, fallbackTitle: book.title ?? "").frame(width: 100, height: 150).clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous)).shadow(color: Color.black.opacity(0.1), radius: 4, y: 2).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.05), lineWidth: 0.5))
            VStack(alignment: .center, spacing: 4) {
                Text(book.title ?? "未知").font(.system(size: 13, weight: .bold)).multilineTextAlignment(.center).lineLimit(1)
                Text(book.author ?? "未知").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary).multilineTextAlignment(.center).lineLimit(1)
            }.frame(maxWidth: .infinity)
        }
    }
}
#endif
