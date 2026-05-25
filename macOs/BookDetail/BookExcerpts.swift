#if os(macOS)
import SwiftUI
import SwiftData

// MARK: - ✨ 双列瀑布流碎片渲染引擎
struct BookExcerpts: View {
    let book: Book
    let isDeleteMode: Bool
    
    // ✨ 修改为传入 Excerpt
    let onDelete: (Excerpt) -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var itemToEdit: Excerpt? = nil
    
    @State private var currentFilter: BookExcerptFilter = .all
    
    // ✨ 核心重构：从单表中一次性取出，自带时间排序，不再需要人造缝合！
    private var allRecords: [Excerpt] {
        return (book.excerpts ?? []).sorted { $0.createdAt > $1.createdAt }
    }
    
    private var filteredRecords: [Excerpt] {
        allRecords.filter(currentFilter.includes)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            if !allRecords.isEmpty {
                HStack {
                    HStack(spacing: 4) {
                        ForEach(BookExcerptFilter.allCases, id: \.self) { filter in
                            FilterTab(
                                title: "\(filter.displayName) (\(filter.count(in: allRecords)))",
                                isSelected: currentFilter == filter
                            ) {
                                currentFilter = filter
                            }
                        }
                    }
                    .padding(4)
                    .appInnerCapsuleStyle()
                    
                    Spacer()
                }
            }
            
            if filteredRecords.isEmpty {
                EmptyView()
            } else {
                WaterfallLayout(columns: 2, spacing: 24) {
                    ForEach(filteredRecords) { item in
                        AnnotationCardWrapper(
                            item: item,
                            isDeleteMode: isDeleteMode,
                            onDelete: { onDelete(item) },
                            onEdit: { itemToEdit = item }
                        )
                    }
                }
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
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    if isSelected {
                        Capsule().fill(AppColors.selection)
                    } else if isHovered {
                        Capsule().fill(AppColors.innerBlock(for: colorScheme))
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
    let excerpt: Excerpt
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "text.quote").foregroundColor(.indigo)
                Text("精彩摘录").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.secondary)
                Spacer()
                Text(excerpt.createdAt.formatted(date: .numeric, time: .shortened)).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary.opacity(0.6))
            }

            Text(verbatim: excerpt.content)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundColor(.primary).lineSpacing(8).fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appInnerBlockStyle(cornerRadius: AppRadius.m)
        .onTapGesture(count: 2, perform: onEdit)
    }
}

struct NoteCardView: View {
    let note: Excerpt
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pencil.line").foregroundColor(.purple)
                Text("阅读笔记").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.secondary)
                Spacer()
                Text(note.createdAt.formatted(date: .numeric, time: .shortened)).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary.opacity(0.6))
            }
            Text(verbatim: note.content)
                .font(.system(size: 15)).foregroundColor(.primary).lineSpacing(6).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appInnerBlockStyle(cornerRadius: AppRadius.m)
        .onTapGesture(count: 2, perform: onEdit)
    }
}

struct BookExcerptsEmptyStateView: View {
    var body: some View {
        EmptyView()
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
