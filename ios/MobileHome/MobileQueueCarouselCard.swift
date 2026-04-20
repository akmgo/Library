#if os(iOS)
import SwiftUI
import SwiftData

// MARK: - 📚 待读画廊列车

/// 横向滚动的未读书籍（想读队列）瀑布流画廊。
///
/// **数据与渲染逻辑：**
/// 接收全局的未读书籍列表 (`unreadBooks`)，最多截取前 10 本。
/// 使用了 `ScrollView(.horizontal)` 构建横滑体验，点击任一封面可无缝 `NavigationLink` 推入详情页。
struct MobileQueueCarouselCard: View {
    let unreadBooks: [Book]
    
    var body: some View {
        GroupBox {
            if unreadBooks.isEmpty {
                VStack {
                    Text("暂无想读计划")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(unreadBooks.prefix(10)) { book in
                            NavigationLink(destination: MobileBookDetailView(book: book)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    LocalCoverView(coverData: book.coverData, fallbackTitle: book.title ?? "")
                                        .frame(width: 80, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                                    
                                    Text(book.title ?? "未知")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(width: 80, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 8)
            }
        } label: {
            HStack {
                Text("想读列车")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "sparkles.rectangle.stack")
                    .foregroundColor(.orange)
            }
        }
    }
}
#endif
