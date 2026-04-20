#if os(macOS)
import SwiftUI
import SwiftData

// MARK: - 🎨 在读焦点视图

/// macOS 主页核心的“当前在读”大幅展示区组件。
///
/// **交互与视觉逻辑：**
/// 核心包含一个与系统 `namespace` 绑定的巨幅封面图（支持悬停放大、点击触发缩放转场），
/// 以及排版优雅的书籍元信息和水平阅读进度条。
struct FluidReadingHero: View {
    let book: Book
    let progress: Double
    let namespace: Namespace.ID
    @Binding var selectedBook: Book?
    @Binding var activeCoverID: String
    
    let allBooks: [Book]
    let allRecords: [ReadingRecord]
    
    @State private var isHovered = false
    
    var body: some View {
        let safeTitle = book.title ?? "未知"
        let safeAuthor = book.author ?? "未知作者"
        let normalizedProgress = min(max(progress / 100.0, 0), 1.0)
        
        HStack(alignment: .center, spacing: 40) {
            ZStack {
                if selectedBook?.id != book.id {
                    LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                        .frame(width: 170, height: 245)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .matchedGeometryEffect(id: "hero-\(book.id ?? UUID().uuidString)", in: namespace)
                        .shadow(color: Color.black.opacity(isHovered ? 0.3 : 0.15), radius: isHovered ? 20 : 12, y: isHovered ? 12 : 8)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                } else {
                    LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                        .frame(width: 170, height: 245).opacity(0.001)
                }
            }
            .onHover { h in withAnimation(.spring()) { isHovered = h }; if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            .onTapGesture { activeCoverID = "hero-\(book.id ?? UUID().uuidString)"; withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { selectedBook = book } }
            
            VStack(alignment: .leading, spacing: 0) {
                Text("CURRENTLY READING").font(.system(size: 11, weight: .black, design: .rounded)).foregroundColor(.blue).tracking(2).padding(.bottom, 6)
                Text(safeTitle).font(.system(size: 36, weight: .heavy, design: .serif)).foregroundColor(.primary).lineLimit(2).minimumScaleFactor(0.8)
                Text(safeAuthor).font(.system(size: 16, weight: .semibold)).foregroundColor(.secondary).lineLimit(1).padding(.top, 4)
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .lastTextBaseline) { Text("\(Int(progress))%").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.primary); Spacer() }
                    ProgressView(value: normalizedProgress).progressViewStyle(.linear).tint(.primary)
                }
            }
            .frame(height: 220)
        }
    }
}

// MARK: - 🎨 在读焦点空状态

/// 主页处于“无在读书籍”状态时的优雅占位组件。
struct FluidEmptyReadingHero: View {
    let allBooks: [Book]
    let allRecords: [ReadingRecord]
    
    var body: some View {
        HStack(alignment: .center, spacing: 40) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])).frame(width: 170, height: 245).background(Color.secondary.opacity(0.02)).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(spacing: 12) {
                    Image(systemName: "book.closed").font(.system(size: 32, weight: .light)).foregroundColor(.secondary.opacity(0.4))
                    Text("暂无在读").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(.secondary.opacity(0.5))
                }
            }
            .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            
            VStack(alignment: .leading, spacing: 0) {
                Text("CURRENTLY READING").font(.system(size: 11, weight: .black, design: .rounded)).foregroundColor(.secondary.opacity(0.3)).tracking(2).padding(.bottom, 6)
                Text("虚位以待").font(.system(size: 36, weight: .heavy, design: .serif)).foregroundColor(.primary.opacity(0.4)).lineLimit(2)
                Text("去书库中挑选一本开启新旅程吧").font(.system(size: 16, weight: .medium)).foregroundColor(.secondary.opacity(0.5)).lineLimit(1).padding(.top, 4)
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .lastTextBaseline) { Text("0%").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.secondary.opacity(0.3)); Spacer() }
                    ProgressView(value: 0).progressViewStyle(.linear).tint(.secondary.opacity(0.2))
                }
            }
            .frame(height: 220)
        }
    }
}
#endif
