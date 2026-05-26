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

    private var snapshot: ReadingStatsCalculator.BookExcerptListSnapshot {
        ReadingStatsCalculator.BookExcerptListSnapshot(
            excerpts: book.excerpts ?? [],
            filter: filter
        )
    }

    private var recordsByID: [String: Excerpt] {
        Dictionary(uniqueKeysWithValues: (book.excerpts ?? []).map { ($0.id, $0) })
    }

    var body: some View {
        if snapshot.isEmpty {
            EmptyView()
        } else {
            AppSlidingSegmentedControl(
                selection: $filter,
                options: BookExcerptFilter.allCases.map {
                    AppSlidingSegmentedOption(value: $0, title: "\($0.displayName) (\(snapshot.count(for: $0)))")
                },
                tint: AppColors.selection,
                height: 32,
                cornerRadius: AppRadius.m,
                showsIcons: false
            )
            .frame(maxWidth: 280)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)

            MobileAnnotationList(
                annotations: snapshot.filtered,
                isDeleteMode: isDeleteMode,
                onDelete: { annotation in
                    if let record = recordsByID[annotation.id] {
                        onDelete(record)
                    }
                }
            )
            .equatable()
        }
    }
}

// MARK: - 📱 卡片包装器与子渲染节点

/// 将原生的笔记/摘录卡片与编辑状态下的“删除热区”复合。
private struct MobileAnnotationList: View, Equatable {
    let annotations: [ReadingStatsCalculator.BookExcerptItemSnapshot]
    let isDeleteMode: Bool
    let onDelete: (ReadingStatsCalculator.BookExcerptItemSnapshot) -> Void

    static func == (lhs: MobileAnnotationList, rhs: MobileAnnotationList) -> Bool {
        lhs.annotations == rhs.annotations && lhs.isDeleteMode == rhs.isDeleteMode
    }

    var body: some View {
        LazyVStack(spacing: AppSpacing.m) {
            ForEach(annotations) { annotation in
                MobileAnnotationCardWrapper(annotation: annotation, isDeleteMode: isDeleteMode) {
                    onDelete(annotation)
                }
            }
        }
    }
}

private struct MobileAnnotationCardWrapper: View {
    let annotation: ReadingStatsCalculator.BookExcerptItemSnapshot
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
    let annotation: ReadingStatsCalculator.BookExcerptItemSnapshot
    
    var body: some View {
        AppCard {
            BookExcerptCardContent(item: annotation, contentFontSize: 15)
        }
    }
}

/// 以纯文本呈现的独立思考笔记视图卡片。
private struct MobileNoteCard: View {
    let annotation: ReadingStatsCalculator.BookExcerptItemSnapshot

    var body: some View {
        AppCard {
            BookExcerptCardContent(item: annotation, contentFontSize: 14)
        }
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
