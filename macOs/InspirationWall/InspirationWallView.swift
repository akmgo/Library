#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

enum ExcerptWallDisplayMode: Equatable {
    case compact
    case artistic
}

private struct ExcerptSpanMasonryLayout: Layout {
    let columns: Int
    let spacing: CGFloat
    let spans: [Int]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 1200
        let columnWidth = (width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        var heights = Array(repeating: CGFloat(0), count: columns)

        for (index, subview) in subviews.enumerated() {
            let span = spanForItem(at: index)
            let placement = findPlacement(for: span, in: heights)
            let proposalWidth = columnWidth * CGFloat(span) + spacing * CGFloat(span - 1)
            let size = subview.sizeThatFits(ProposedViewSize(width: proposalWidth, height: nil))
            let newY = placement.y + size.height + spacing

            for column in placement.column..<(placement.column + span) {
                heights[column] = newY
            }
        }

        return CGSize(width: width, height: heights.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columnWidth = (bounds.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        var heights = Array(repeating: bounds.minY, count: columns)

        for (index, subview) in subviews.enumerated() {
            let span = spanForItem(at: index)
            let placement = findPlacement(for: span, in: heights)
            let x = bounds.minX + CGFloat(placement.column) * (columnWidth + spacing)
            let y = placement.y
            let proposalWidth = columnWidth * CGFloat(span) + spacing * CGFloat(span - 1)

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: proposalWidth, height: nil))
            let size = subview.sizeThatFits(ProposedViewSize(width: proposalWidth, height: nil))
            let newY = y + size.height + spacing

            for column in placement.column..<(placement.column + span) {
                heights[column] = newY
            }
        }
    }

    private func spanForItem(at index: Int) -> Int {
        min(max(1, spans.indices.contains(index) ? spans[index] : 1), columns)
    }

    private func findPlacement(for span: Int, in heights: [CGFloat]) -> (column: Int, y: CGFloat) {
        var bestColumn = 0
        var minY = CGFloat.infinity

        for column in 0...(columns - span) {
            let maxYInSpan = heights[column..<(column + span)].max() ?? 0
            if maxYInSpan < minY {
                minY = maxYInSpan
                bestColumn = column
            }
        }

        return (bestColumn, minY)
    }
}

// MARK: - ✨ 灵感画廊 (核心视图)

struct InspirationWallView: View {
    @Environment(\.modelContext) private var modelContext
    let filterCategory: ExcerptCategory?
    let sortKey: AnnotationSortKey
    let displayMode: ExcerptWallDisplayMode
    @Binding var isBatchDeletePresented: Bool
    @Binding var selectedExcerptIDs: Set<String>
    @Query private var allExcerpts: [Excerpt]
    
    @State private var shuffledExcerpts: [ExcerptListItem] = []
    @State private var scrolledExcerptID: String?
    
    @State private var recordToEdit: Excerpt? = nil
    
    private var annotationFingerprint: String {
        allExcerpts
            .map { "\($0.id)|\($0.type.rawValue)|\($0.createdAt.timeIntervalSince1970)|\($0.content.hashValue)|\($0.book?.id ?? "")" }
            .joined(separator: ";")
            + "|\(filterCategory?.rawValue ?? "all")|\(sortKey)|\(displayMode)"
    }
    
    var body: some View {
        let totalExcerptCharacters = shuffledExcerpts.reduce(0) { $0 + $1.content.count }
        let uniqueBooksCount = Set(shuffledExcerpts.map(\.bookID)).filter { !$0.isEmpty }.count
        
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack {
                    wallContentView(containerSize: geo.size)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity)
            }
            .overlay(alignment: .top) {
                AppPageHeader(
                    contentID: "\(shuffledExcerpts.count)-\(totalExcerptCharacters)-\(uniqueBooksCount)-\(filterCategory?.rawValue ?? "all")-\(sortKey)-\(displayMode)"
                ) {
                    AppHeaderTitle("摘录长廊", subtitle: "书中摘录与日常片段汇集于此。")
            } trailingContent: { PageStatsCompact(items: excerptHeaderStats) }
            }
            .overlay(alignment: .bottom) {
                if isBatchDeletePresented {
                    excerptBatchDeleteCapsule
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(item: $recordToEdit) { record in
                ExcerptEditorSheet(
                    isPresented: Binding(
                        get: { recordToEdit != nil },
                        set: { isPresented in
                            if !isPresented {
                                recordToEdit = nil
                                refreshData(animate: false)
                            }
                        }
                    ),
                    excerptToEdit: record
                )
            }
            .onAppear {
                refreshData(animate: false)
            }
            .onChange(of: annotationFingerprint) { _, _ in refreshData(animate: true) }
        }
    }
    
    @ViewBuilder
    private func wallContentView(containerSize: CGSize) -> some View {
        if shuffledExcerpts.isEmpty {
            EmptyStateView(
                systemImage: "leaf",
                title: "空空如也",
                message: "多读书，多记录，这里会长出智慧的森林。",
                minHeight: 400
            )
            .padding(.top, AppPageHeaderMetrics.height + 12)
        } else {
            switch displayMode {
            case .compact:
                masonryGrid(containerWidth: containerSize.width)
            case .artistic:
                carouselView(containerSize: containerSize)
            }
        }
    }

    private func carouselView(containerSize: CGSize) -> some View {
        let viewportHeight = max(520, containerSize.height - AppPageHeaderMetrics.height - 92)

        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(shuffledExcerpts) { excerpt in
                    ZStack(alignment: .center) {
                        selectableExcerptCard(excerpt)
                            .frame(width: min(800, max(320, containerSize.width - 120)))
                            .scrollTransition(axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1.0 : 0.85)
                                    .opacity(phase.isIdentity ? 1.0 : 0.3)
                                    .offset(y: phase.isIdentity ? 0 : 30)
                            }
                    }
                    .frame(width: containerSize.width)
                    .frame(minHeight: viewportHeight, alignment: .center)
                    .id(excerpt.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrolledExcerptID)
        .scrollTargetBehavior(.viewAligned)
        .padding(.top, AppPageHeaderMetrics.height + 32)
        .padding(.bottom, 60)
        .onChange(of: scrolledExcerptID) { oldValue, newValue in
            if oldValue != newValue, newValue != nil {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
        }
    }

    @ViewBuilder
    private func masonryGrid(containerWidth: CGFloat) -> some View {
        let minColumnWidth: CGFloat = 280
        let spacing: CGFloat = 24
        let horizontalPadding: CGFloat = 80
        let availableWidth = max(minColumnWidth, containerWidth - horizontalPadding)
        let columnsCount = availableWidth >= 680 ? 2 : 1
        let spans = shuffledExcerpts.map { columnSpan(for: $0, columnsCount: columnsCount) }

        ExcerptSpanMasonryLayout(columns: columnsCount, spacing: spacing, spans: spans) {
            ForEach(shuffledExcerpts) { excerpt in
                selectableExcerptCard(excerpt)
                    .transition(.appCardGlide)
            }
        }
        .frame(width: availableWidth)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 40).padding(.top, AppPageHeaderMetrics.height + 32).padding(.bottom, 60)
    }

    private func columnSpan(for excerpt: ExcerptListItem, columnsCount: Int) -> Int {
        guard columnsCount > 1 else { return 1 }
        switch excerpt.category {
        case .prose, .note:
            return 2
        case .bookExcerpt, .poetry, .lyric, .quote, .web, .movie:
            return 1
        }
    }

    private var excerptHeaderStats: [PageStatItemData] {
        let total = allExcerpts.count
        let bookExcerptCount = allExcerpts.filter { $0.category == .bookExcerpt }.count
        let uniqueBooks = Set(allExcerpts.compactMap { $0.book?.title }).count
        let thisWeek = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let newThisWeek = allExcerpts.filter { $0.createdAt >= thisWeek }.count
        return [
            PageStatItemData(title: "全部摘录", value: "\(total)", color: .indigo),
            PageStatItemData(title: "书中摘录", value: "\(bookExcerptCount)", color: AppColors.readingAmber),
            PageStatItemData(title: "知识源泉", value: "\(uniqueBooks)", color: .teal),
            PageStatItemData(title: "本周新增", value: "\(newThisWeek)", color: .pink),
        ]
    }

    private func selectableExcerptCard(_ excerpt: ExcerptListItem) -> some View {
        ExcerptWallCardView(
            excerpt: excerpt,
            onEdit: { item in triggerEdit(for: item) },
            allowsEditGesture: !isBatchDeletePresented
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(isBatchDeletePresented && selectedExcerptIDs.contains(excerpt.id) ? Color.blue : Color.clear, lineWidth: 3)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isBatchDeletePresented {
                toggleSelection(for: excerpt)
            }
        }
    }
}

// MARK: - ✨ 核心数据引擎调度与方法

extension InspirationWallView {
    
    @MainActor
    private func triggerEdit(for excerpt: ExcerptListItem) {
        let targetID = excerpt.id
        if let target = allExcerpts.first(where: { $0.id == targetID }) {
            self.recordToEdit = target
        }
    }

    private func refreshData(animate: Bool) {
        Task { @MainActor in
            let newData = fetchAndProcessExcerpts()
            
            if animate {
                withAnimation(.appContentFade) { self.shuffledExcerpts = newData }
            } else {
                self.shuffledExcerpts = newData
            }
        }
    }
    
    @MainActor
    private func fetchAndProcessExcerpts() -> [ExcerptListItem] {
        ReadingStatsCalculator.inspirationSnapshot(
            excerpts: allExcerpts,
            type: filterCategory,
            searchText: "",
            sortKey: sortKey,
            randomize: false
        ).excerpts
    }
    
    private func toggleSelection(for excerpt: ExcerptListItem) {
        if selectedExcerptIDs.contains(excerpt.id) {
            selectedExcerptIDs.remove(excerpt.id)
        } else {
            selectedExcerptIDs.insert(excerpt.id)
        }
    }

    private var selectedExcerpts: [Excerpt] {
        allExcerpts.filter { selectedExcerptIDs.contains($0.id) }
    }

    private var excerptBatchDeleteCapsule: some View {
        HStack(spacing: 14) {
            Button {
                withAnimation(.appContentFade) {
                    selectedExcerptIDs.removeAll()
                    isBatchDeletePresented = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("取消")

            Text("已选择 \(selectedExcerptIDs.count) 条")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(minWidth: 88)

            Button(role: .destructive) {
                deleteSelectedExcerpts()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(selectedExcerptIDs.isEmpty)
            .help("删除")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }

    private func deleteSelectedExcerpts() {
        do {
            try ReadingDataService.shared.deleteExcerpts(selectedExcerpts, context: modelContext)
            withAnimation(.appContentFade) {
                selectedExcerptIDs.removeAll()
                isBatchDeletePresented = false
                refreshData(animate: true)
            }
        } catch {
            print("删除摘录失败: \(error.localizedDescription)")
        }
    }
}

#endif
