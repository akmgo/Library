#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 🧩 混合列表渲染引擎 (全面拥抱大一统注解模型)

/// 并列交织渲染书籍关联的所有碎片记录的双列瀑布流容器。
///
/// **逻辑与交互：**
/// 彻底废弃了曾经繁琐的 Excerpt 和 Note 双表异构拼装。
/// 如今直接从 book 实体中提取统一的 `annotations` 进行倒序排列渲染。
struct MobileExcerptsAndNotesList: View {
    let book: Book
    let isDeleteMode: Bool
    
    /// 当用户点击红色 "X" 按钮时触发的业务上移执行闭包。
    /// ✨ 修复：传出参数统一更改为原生的 Excerpt
    let onDelete: (Excerpt) -> Void

    @State private var filter: BookExcerptFilter = .all
    @Environment(\.colorScheme) private var colorScheme

    private var sortedAnnotations: [Excerpt] {
        (book.excerpts ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    private var filteredAnnotations: [Excerpt] {
        sortedAnnotations.filter(filter.includes)
    }

    var body: some View {
        if sortedAnnotations.isEmpty {
            VStack(spacing: AppSpacing.s) {
                Image(systemName: "leaf").font(.system(size: 32)).foregroundColor(Color.gray.opacity(0.5))
                Text("暂无记录，写下你的感悟吧").font(.system(size: 14)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else {
            HStack(spacing: AppSpacing.xxs) {
                ForEach(BookExcerptFilter.allCases, id: \.self) { f in
                    let count = f.count(in: sortedAnnotations)
                    Button(action: { withAnimation { filter = f } }) {
                        Text("\(f.displayName) (\(count))")
                            .font(.system(size: 12, weight: filter == f ? .bold : .medium, design: .rounded))
                            .foregroundColor(filter == f ? AppColors.primaryBackground(for: colorScheme) : .primary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(filter == f ? Color.primary : Color.secondary.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.bottom, 8)

            LazyVStack(spacing: AppSpacing.m) {
                ForEach(filteredAnnotations) { annotation in
                    MobileAnnotationCardWrapper(annotation: annotation, isDeleteMode: isDeleteMode) {
                        onDelete(annotation)
                    }
                }
            }
        }
    }
}

// MARK: - 📱 卡片包装器与子渲染节点

/// 将原生的笔记/摘录卡片与编辑状态下的“删除热区”复合。
private struct MobileAnnotationCardWrapper: View {
    let annotation: Excerpt
    let isDeleteMode: Bool
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                // ✨ 自动根据模型内的类型属性分发不同 UI 卡片
                if annotation.isNote {
                    MobileNoteCard(annotation: annotation)
                } else {
                    MobileReadingExcerptCard(annotation: annotation)
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
                        .shadow(color: AppColors.danger.opacity(0.4), radius: 6, y: 3)
                }
                .offset(x: 8, y: -8)
                .transition(.scale.combined(with: .opacity))
                .zIndex(1)
            }
        }
    }
}

/// 基于衬线体 (`.serif`) 的优雅原书划线展示模块。
private struct MobileReadingExcerptCard: View {
    let annotation: Excerpt
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            // ✨ 修复：模型里的 content 已经是必填项，干掉了冗余的 ?? ""
            Text(verbatim: annotation.content)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .lineSpacing(6)
                .foregroundColor(.primary)
            
            HStack {
                Spacer()
                // ✨ 修复：同理干掉 ?? Date()
                Text(annotation.createdAt, format: .dateTime.year().month().day())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.gray.opacity(0.5))
            }
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appInnerCardStyle()
    }
}

/// 以纯文本呈现的独立思考笔记视图卡片。
private struct MobileNoteCard: View {
    let annotation: Excerpt
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(verbatim: annotation.content)
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundColor(.primary)
            
            HStack {
                Spacer()
                Text(annotation.createdAt, format: .dateTime.year().month().day())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.gray.opacity(0.5))
            }
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appInnerCardStyle()
    }
}

#if DEBUG
private struct PreviewExcerptsList: View {
    var body: some View {
        PreviewWithBook(title: "三体", author: "刘慈欣", currentAmount: 156) { book in
            MobileExcerptsAndNotesList(
                book: book,
                isDeleteMode: false,
                onDelete: { _ in }
            )
        }
        .modelContainer(previewModelContainer)
    }
}

#Preview("摘录与笔记列表") {
    PreviewExcerptsList()
}
#endif


#endif
