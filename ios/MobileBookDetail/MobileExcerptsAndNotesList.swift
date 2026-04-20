#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 全局抽象数据流模型

/// 用于抹平底层 `Excerpt` (摘录) 和 `Note` (笔记) 不同表结构的包装器载体。
enum MobileRecordItem: Identifiable {
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

// MARK: - 🧩 混合列表渲染引擎 (全面拥抱原生 Markdown)

/// 并列交织渲染书籍关联的所有碎片记录的双列瀑布流容器。
///
/// **逻辑与交互：**
/// 该视图会将所有拉取到的数据整合、依照时间倒序排列，然后通过数学模取 (`offset % 2`) 的方法强行平分到左右两侧 `VStack`。
/// 它接收上级组件下放的 `isDeleteMode`，可对所有子卡片呈现可删除红点样式。
struct MobileExcerptsAndNotesList: View {
    let book: Book
    let isDeleteMode: Bool
    
    /// 当用户点击红色 "X" 按钮时触发的业务上移执行闭包。
    let onDelete: (MobileRecordItem) -> Void
    
    private var mixedRecords: [MobileRecordItem] {
        let excerpts = (book.excerpts ?? []).map { MobileRecordItem.excerpt($0) }
        let notes = (book.notes ?? []).map { MobileRecordItem.note($0) }
        return (excerpts + notes).sorted { $0.date > $1.date }
    }
    
    var body: some View {
        if mixedRecords.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "leaf").font(.system(size: 32)).foregroundColor(Color.gray.opacity(0.5))
                Text("暂无记录，写下你的感悟吧").font(.system(size: 14)).foregroundColor(.secondary)
            }
            .padding(.vertical, 60)
        } else {
            LazyVStack(spacing: 16) {
                ForEach(mixedRecords) { item in
                    MobileRecordCardWrapper(item: item, isDeleteMode: isDeleteMode) { onDelete(item) }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - 📱 卡片包装器与子渲染节点

/// 将原生的笔记/摘录卡片与编辑状态下的“删除热区”复合。
private struct MobileRecordCardWrapper: View {
    let item: MobileRecordItem
    let isDeleteMode: Bool
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch item {
                case .excerpt(let excerpt): MobileExcerptCard(excerpt: excerpt)
                case .note(let note): MobileNoteCard(note: note)
                }
            }
            
            // 漂浮在右上角的删除按钮引擎
            if isDeleteMode {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.red)
                        .clipShape(Circle())
                        .shadow(color: Color.red.opacity(0.4), radius: 6, y: 3)
                }
                .offset(x: 8, y: -8)
                .transition(.scale.combined(with: .opacity))
                .zIndex(1)
            }
        }
    }
}

/// 基于衬线体 (`.serif`) 的优雅原书划线展示模块。
private struct MobileExcerptCard: View {
    let excerpt: Excerpt
    var body: some View {
        let safeContent = excerpt.content ?? ""
        let safeDate = excerpt.createdAt ?? Date()
        
        VStack(alignment: .leading, spacing: 12) {
            // 🍏 LocalizedStringKey 魔法，支持将存储的 markdown 粗体直接转出格式
            Text(LocalizedStringKey(safeContent))
                .font(.system(size: 15, weight: .regular, design: .serif))
                .lineSpacing(6)
                .foregroundColor(.primary)
            HStack {
                Spacer()
                Text(safeDate, format: .dateTime.year().month().day())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.gray.opacity(0.5))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// 呈现原生 Markdown 并带有橙紫暖色辨识特征的独立思考笔记视图卡片。
private struct MobileNoteCard: View {
    let note: Note
    var body: some View {
        let safeContent = note.content ?? ""
        let safeDate = note.createdAt ?? Date()
        
        VStack(alignment: .leading, spacing: 12) {
            // 🍏 SwiftUI 底层自动接管 markdown 的多级 Header 和无序列表样式映射
            Text(LocalizedStringKey(safeContent))
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundColor(.primary)
            HStack {
                Spacer()
                Text(safeDate, format: .dateTime.year().month().day())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.gray.opacity(0.5))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.05)) // 笔记用极淡的暖黄色区分，并带底层阴影
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
#endif
