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
    
    // ✨ 极简提取：由于单表合并，现在只需要一句话就能完成排序
    private var sortedAnnotations: [Excerpt] {
        (book.excerpts ?? []).sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        if sortedAnnotations.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "leaf").font(.system(size: 32)).foregroundColor(Color.gray.opacity(0.5))
                Text("暂无记录，写下你的感悟吧").font(.system(size: 14)).foregroundColor(.secondary)
            }
            .padding(.vertical, 60)
        } else {
            LazyVStack(spacing: 16) {
                ForEach(sortedAnnotations) { annotation in
                    MobileAnnotationCardWrapper(annotation: annotation, isDeleteMode: isDeleteMode) {
                        onDelete(annotation)
                    }
                }
            }
            .padding(.horizontal, 20)
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
private struct MobileReadingExcerptCard: View {
    let annotation: Excerpt
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ✨ 修复：模型里的 content 已经是必填项，干掉了冗余的 ?? ""
            Text(annotation.content)
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondaryBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous))
    }
}

/// 呈现原生 Markdown 并带有橙紫暖色辨识特征的独立思考笔记视图卡片。
private struct MobileNoteCard: View {
    let annotation: Excerpt
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 🍏 SwiftUI 底层自动接管 markdown 的多级 Header 和无序列表样式映射
            Text(annotation.content)
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.05)) // 笔记用极淡的暖黄色区分，并带底层阴影
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous))
    }
}
#endif
