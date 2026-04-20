#if os(macOS)
import SwiftUI
import SwiftData

// MARK: - ✨ 双列瀑布流碎片渲染引擎

/// 混合渲染书籍内所有“摘录”与“笔记”列表的组件。
///
/// **排版特征：**
/// 为了利用横向空间，它会根据记录索引对数据进行按奇偶分发，实现类似 Pinterest 的双列等宽瀑布流。
/// 支持响应外层的 `isDeleteMode` 状态，在卡片右上角弹射删除按钮。
struct BookExcerptsView: View {
    let book: Book
    /// 由外层 `BookDetailView` 控制的危险状态锁
    let isDeleteMode: Bool
    /// 执行实际数据库删除操作的逃逸闭包
    let onDelete: (RecordItem) -> Void
    
    /// 将 `Excerpt` 和 `Note` 统一转化为抽象的 `RecordItem` 枚举并按时间倒序排列。
    private var mixedRecords: [RecordItem] {
        let excerpts = (book.excerpts ?? []).map { RecordItem.excerpt($0) }
        let notes = (book.notes ?? []).map { RecordItem.note($0) }
        return (excerpts + notes).sorted { $0.date > $1.date }
    }
    
    var body: some View {
        if mixedRecords.isEmpty {
            EmptyStateView()
        } else {
            // 通过奇偶校验，将单列流分摊为双列
            let leftColumn = mixedRecords.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }
            let rightColumn = mixedRecords.enumerated().filter { $0.offset % 2 != 0 }.map { $0.element }
            
            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 24) {
                    ForEach(leftColumn) { item in
                        RecordCardWrapper(item: item, isDeleteMode: isDeleteMode) { onDelete(item) }
                    }
                }
                VStack(spacing: 24) {
                    ForEach(rightColumn) { item in
                        RecordCardWrapper(item: item, isDeleteMode: isDeleteMode) { onDelete(item) }
                    }
                }
            }
        }
    }
}

// MARK: - 数据包装器

/// 用于抹平异构数据表差异的统一枚举载体。
enum RecordItem: Identifiable {
    case excerpt(Excerpt)
    case note(Note)
    
    var id: String {
        switch self {
        case .excerpt(let e): return "excerpt-\(e.id ?? UUID().uuidString)"
        case .note(let n): return "note-\(n.id ?? UUID().uuidString)"
        }
    }
    
    var date: Date {
        switch self {
        case .excerpt(let e): return e.createdAt ?? Date.distantPast
        case .note(let n): return n.createdAt ?? Date.distantPast
        }
    }
}

// MARK: - 内部视图组件

/// 负责根据枚举类型路由到具体卡片视图，并在顶层覆盖动画删除按钮。
private struct RecordCardWrapper: View {
    let item: RecordItem; let isDeleteMode: Bool; let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch item {
                case .excerpt(let excerpt): ExcerptCardView(excerpt: excerpt)
                case .note(let note): NoteCardView(note: note)
                }
            }
            if isDeleteMode {
                Button(action: onDelete) {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        .frame(width: 24, height: 24).background(Color.red).clipShape(Circle())
                        .shadow(color: Color.red.opacity(0.4), radius: 4, y: 2)
                }
                .buttonStyle(.plain).offset(x: 10, y: -10)
                .transition(.scale.combined(with: .opacity)).zIndex(1)
            }
        }
    }
}

/// 呈现原生原文划线的摘录卡片。采用靛青色调与衬线字体增强阅读感。
private struct ExcerptCardView: View {
    let excerpt: Excerpt
    var body: some View {
        let safeContent = excerpt.content ?? "无内容"
        let safeDate = excerpt.createdAt ?? Date()
        
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "quote.opening").font(.system(size: 32, weight: .black)).foregroundColor(Color.secondary.opacity(0.2))
            
            Text(LocalizedStringKey(safeContent))
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundColor(.primary).lineSpacing(8).fixedSize(horizontal: false, vertical: true)
                
            HStack {
                Spacer()
                Text("—— \(safeDate.formatted(date: .numeric, time: .shortened))").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary.opacity(0.6))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
    }
}

/// 呈现用户自主心得的笔记卡片。采用橙紫暖色系进行视觉区隔。
private struct NoteCardView: View {
    let note: Note
    var body: some View {
        let safeContent = note.content ?? ""
        let safeDate = note.createdAt ?? Date()
        
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pencil.line").foregroundColor(.purple)
                Text("阅读笔记").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.secondary)
                Spacer()
                Text(safeDate.formatted(date: .numeric, time: .shortened)).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary.opacity(0.6))
            }
            
            Text(LocalizedStringKey(safeContent))
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .lineSpacing(6)
                .textSelection(.enabled) // 允许鼠标拖拽框选文字
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.orange.opacity(0.15), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
    }
}

/// 在一本书没有任何记录时展示的高雅空状态提示占位符。
private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("没有任何思考的痕迹").font(.system(size: 16, weight: .bold)).foregroundColor(.secondary)
            Text("点击右上角的按钮，沉淀当下的思绪").font(.system(size: 13)).foregroundColor(.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity).frame(height: 200)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.secondary.opacity(0.1), style: StrokeStyle(lineWidth: 1.5, dash: [8, 8])))
    }
}
#endif
