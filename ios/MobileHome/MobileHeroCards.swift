#if os(iOS)
import SwiftUI
import SwiftData

// MARK: - 🌟 顶部焦点区域组件

/// 移动端首屏的“当前在读”大幅图文卡片。
///
/// **视觉特性：**
/// 提供 2:3 比例的标准书籍封面渲染，附带醒目的书名、作者以及一条反映整体阅读完成度（0-100%）的横向渐变进度条。
struct MobileReadingHeroCard: View {
    let book: Book
    var body: some View {
        let safeTitle = book.title ?? "未知书名"
        let safeAuthor = book.author ?? "未知作者"
        let progress = Double(book.progress)
        
        GroupBox {
            HStack(alignment: .top, spacing: 20) {
                LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                    .frame(width: 90, height: 135)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 6, y: 3)
                
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(safeTitle)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Text(safeAuthor)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 16)
                    
                    // 底部：纯粹舒展的进度条
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .lastTextBaseline) {
                            Text("当前进度")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(progress))%")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(.blue)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.15))
                                Capsule().fill(Color.blue.gradient).frame(width: geo.size.width * CGFloat(progress / 100.0))
                            }
                        }.frame(height: 8)
                    }
                }
            }
        } label: {
            HStack {
                Text("在读焦点").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "book.closed.fill").foregroundColor(.blue)
            }
        }
    }
}

/// 主页尚未设置在读书籍时的优雅占位提示卡片。
struct MobileEmptyReadingCard: View {
    var body: some View {
        GroupBox {
            VStack(spacing: 16) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("书海浩瀚，寻找下一段旅程")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        } label: {
            HStack {
                Text("在读焦点").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "book.closed.fill").foregroundColor(.blue)
            }
        }
    }
}
#endif
