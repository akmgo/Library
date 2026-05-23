#if os(macOS)
import SwiftUI
import SwiftData

// MARK: - ✨ 过滤器枚举
enum AnnotationFilter: String, CaseIterable {
    case all = "全部"
    case excerpts = "摘录"
    case notes = "笔记"
}

// MARK: - ✨ 双列瀑布流碎片渲染引擎
struct BookExcerpts: View {
    let book: Book
    let isDeleteMode: Bool
    
    // ✨ 修改为传入 Excerpt
    let onDelete: (Excerpt) -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var itemToEdit: Excerpt? = nil
    
    @State private var currentFilter: AnnotationFilter = .all
    
    // ✨ 核心重构：从单表中一次性取出，自带时间排序，不再需要人造缝合！
    private var allRecords: [Excerpt] {
        return (book.excerpts ?? []).sorted { $0.createdAt > $1.createdAt }
    }
    
    private var filteredRecords: [Excerpt] {
        switch currentFilter {
        case .all:
            return allRecords
        case .excerpts:
            return allRecords.filter { $0.type == .excerpt }
        case .notes:
            return allRecords.filter { $0.type == .note }
        }
    }
    
    private var excerptCount: Int { book.excerpts?.filter({ $0.type == .excerpt }).count ?? 0 }
    private var noteCount: Int { book.excerpts?.filter({ $0.type == .note }).count ?? 0 }
    
    var body: some View {
        VStack(spacing: 24) {
            // 顶部：高定分类过滤器
            if !allRecords.isEmpty {
                HStack {
                    HStack(spacing: 4) {
                        FilterTab(title: "全部 (\(excerptCount + noteCount))", isSelected: currentFilter == .all) { currentFilter = .all }
                        FilterTab(title: "摘录 (\(excerptCount))", isSelected: currentFilter == .excerpts) { currentFilter = .excerpts }
                        FilterTab(title: "笔记 (\(noteCount))", isSelected: currentFilter == .notes) { currentFilter = .notes }
                    }
                    .padding(4)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(Capsule())
                    
                    Spacer()
                }
            }
            
            if filteredRecords.isEmpty {
                BookExcerptsEmptyStateView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                WaterfallLayout(columns: 2, spacing: 24) {
                    ForEach(filteredRecords) { item in
                        AnnotationCardWrapper(
                            item: item,
                            isDeleteMode: isDeleteMode,
                            onDelete: { onDelete(item) },
                            onEdit: { itemToEdit = item }
                        )
                        .transition(.appCardGlide)
                    }
                }
                .animation(.appFluidSpring, value: filteredRecords.count)
            }
        }
        .sheet(item: $itemToEdit) { item in
            ContentEditorSheet(
                isPresented: Binding(
                    get: { itemToEdit != nil },
                    set: { isPresented in if !isPresented { itemToEdit = nil } }
                ),
                book: book,
                mode: item.isNote ? .note : .excerpt,
                itemToEdit: item
            )
        }
    }
}

// MARK: - 辅助微件
private struct FilterTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
            .foregroundColor(isSelected ? Color(nsColor: .windowBackgroundColor) : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    if isSelected {
                        Capsule().fill(Color.primary)
                    } else if isHovered {
                        Capsule().fill(Color.secondary.opacity(0.1))
                    }
                }
            )
            .contentShape(Capsule())
            .onHover { h in withAnimation(.easeInOut(duration: 0.2)) { isHovered = h }; if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { action() }
            }
    }
}

// MARK: - 瀑布流 Layout
struct WaterfallLayout: Layout {
    var columns: Int = 2
    var spacing: CGFloat = 24

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        if width <= 0 || subviews.isEmpty { return CGSize(width: width, height: 0) }
        
        let columnWidth = (width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        var columnHeights = Array(repeating: CGFloat(0), count: columns)

        for subview in subviews {
            let minIndex = columnHeights.firstIndex(of: columnHeights.min() ?? 0) ?? 0
            let size = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
            columnHeights[minIndex] += size.height + spacing
        }

        let maxHeight = (columnHeights.max() ?? 0) - spacing
        return CGSize(width: width, height: max(0, maxHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        if bounds.width <= 0 || subviews.isEmpty { return }
        
        let columnWidth = (bounds.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        var columnHeights = Array(repeating: bounds.minY, count: columns)

        for subview in subviews {
            let minIndex = columnHeights.firstIndex(of: columnHeights.min() ?? 0) ?? 0
            
            let x = bounds.minX + CGFloat(minIndex) * (columnWidth + spacing)
            let y = columnHeights[minIndex]

            let size = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
            
            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: columnWidth, height: size.height)
            )

            columnHeights[minIndex] += size.height + spacing
        }
    }
}

// MARK: - 内部视图组件
struct AnnotationCardWrapper: View {
    let item: Excerpt
    let isDeleteMode: Bool
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if item.type == .excerpt {
                    ExcerptCardView(excerpt: item, onEdit: onEdit)
                } else {
                    NoteCardView(note: item, onEdit: onEdit)
                }
            }
            if isDeleteMode {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.red)
                        .clipShape(Circle())
                        .shadow(color: Color.red.opacity(0.4), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .offset(x: 10, y: -10)
                .transition(.scale.combined(with: .opacity))
                .zIndex(1)
            }
        }
    }
}

struct ExcerptCardView: View {
    let excerpt: Excerpt // ✨
    let onEdit: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "text.quote").foregroundColor(.indigo)
                Text("精彩摘录").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.secondary)
                Spacer()
                Text(excerpt.createdAt.formatted(date: .numeric, time: .shortened)).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary.opacity(0.6))
            }
            
            Text(excerpt.content)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundColor(.primary).lineSpacing(8).fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isHovered ? Color.indigo.opacity(0.3) : Color.secondary.opacity(0.1), lineWidth: isHovered ? 1.5 : 1)
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 16 : 10, y: isHovered ? 8 : 4)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        .onHover { h in isHovered = h }
        .onTapGesture(count: 2, perform: onEdit)
    }
}

struct NoteCardView: View {
    let note: Excerpt // ✨
    let onEdit: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pencil.line").foregroundColor(.purple)
                Text("阅读笔记").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.secondary)
                Spacer()
                Text(note.createdAt.formatted(date: .numeric, time: .shortened)).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary.opacity(0.6))
            }
            Text(note.content)
                .font(.system(size: 15)).foregroundColor(.primary).lineSpacing(6).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isHovered ? Color.purple.opacity(0.3) : Color.orange.opacity(0.15), lineWidth: isHovered ? 1.5 : 1)
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 16 : 10, y: isHovered ? 8 : 4)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        .onHover { h in isHovered = h }
        .onTapGesture(count: 2, perform: onEdit)
    }
}

struct BookExcerptsEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("没有任何思考的痕迹").font(.system(size: 16, weight: .bold)).foregroundColor(.secondary)
            Text("点击右上角的按钮，沉淀当下的思绪").font(.system(size: 13)).foregroundColor(.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity).frame(height: 200).background(Color.secondary.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.secondary.opacity(0.1), style: StrokeStyle(lineWidth: 1.5, dash: [8, 8])))
    }
}

struct BookExcerptsPreviewWrapper: View {
    @Query var books: [Book]
    var body: some View {
        if let book = books.first {
            ScrollView {
                BookExcerpts(
                    book: book,
                    isDeleteMode: false,
                    onDelete: { _ in }
                )
                .padding()
            }
            .frame(width: 900, height: 600)
        }
    }
}

#endif
