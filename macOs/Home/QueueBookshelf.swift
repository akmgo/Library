#if os(macOS)
import SwiftUI

// MARK: - 📚 待读列车书架

/// 在界面底部展现“待读列车”前四本序列的书架占位图。
struct FluidQueueBookshelfChart: View {
    // 1. 彻底解耦：只接收纯粹的 UI 数据点数组
    let displayBooks: [QueueBookDataPoint]
    
    var body: some View {
        // ✨ 核心重构：抛弃 GroupBox，换上原生的液态玻璃舱
        VStack(alignment: .leading, spacing: 16) {
            // 头部 Label
            HStack {
                Text("想读焦点")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "sparkles.rectangle.stack")
                    .foregroundColor(.orange)
            }
            
            if displayBooks.isEmpty {
                // 空状态视图
                VStack(spacing: 8) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("暂无想读计划")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                // 数据渲染视图
                HStack(alignment: .top, spacing: 20) {
                    // 渲染传入的书籍
                    ForEach(displayBooks) { book in
                        WantToReadBookItem(book: book)
                            .frame(maxWidth: .infinity)
                    }
                    // 核心逻辑：如果不足 4 本，用 Spacer() 把剩下的位置撑满，保证排版不乱
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
        .padding(24) // 撑开内部空间
        .glassEffect(in: .rect(cornerRadius: 24.0)) // ✨ 注入极致通透的液态玻璃外壳
    }
}

/// 渲染带阴影的小尺寸书籍模型 (带有悬停呼吸感)
private struct WantToReadBookItem: View {
    let book: QueueBookDataPoint
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            // 封面图调用跨端图片组件
            LocalCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                .frame(width: 100, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: Color.black.opacity(isHovered ? 0.2 : 0.1), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.05), lineWidth: 0.5))
                // ✨ 鼠标悬浮放大特效
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
            
            // 书名与作者信息
            VStack(alignment: .center, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 13, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                Text(book.author)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .onHover { h in
            isHovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - 预览
#Preview("待读列车") {
    FluidQueueBookshelfChart(displayBooks: PreviewData.mockQueueBooksData)
        .padding()
        .frame(width: 600, height: 300)
}
#endif
