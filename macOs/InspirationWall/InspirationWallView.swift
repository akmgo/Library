#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

enum ExcerptWallDisplayMode: Equatable {
    case compact
    case artistic
}

// MARK: - ✨ 灵感画廊 (核心视图)

struct InspirationWallView: View {
    @Environment(\.modelContext) private var modelContext
    let filterCategory: ExcerptCategory?
    let sortKey: AnnotationSortKey
    let displayMode: ExcerptWallDisplayMode
    @Binding var isBatchDeletePresented: Bool
    @Binding var selectedExcerptIDs: Set<String>
    @Binding var highlightedExcerptID: String?
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

    private var shuffledFingerprint: String {
        shuffledExcerpts.map(\.id).joined(separator: ";")
    }
    
    var body: some View {
        let totalExcerptCharacters = shuffledExcerpts.reduce(0) { $0 + $1.content.count }
        let uniqueBooksCount = Set(shuffledExcerpts.map(\.bookID)).filter { !$0.isEmpty }.count
        
        GeometryReader { geo in
            ScrollViewReader { proxy in
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
                    scrollToHighlightedExcerpt(highlightedExcerptID, proxy: proxy)
                }
                .onChange(of: annotationFingerprint) { _, _ in refreshData(animate: true) }
                .onChange(of: highlightedExcerptID) { _, id in scrollToHighlightedExcerpt(id, proxy: proxy) }
                .onChange(of: shuffledFingerprint) { _, _ in scrollToHighlightedExcerpt(highlightedExcerptID, proxy: proxy) }
            }
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
        let rows = excerptRows(for: shuffledExcerpts, columnsCount: columnsCount)

        LazyVStack(spacing: spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                if row.count == 1 && columnSpan(for: row[0], columnsCount: columnsCount) == columnsCount {
                    selectableExcerptCard(row[0])
                        .frame(maxWidth: .infinity)
                } else {
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(row) { excerpt in
                            selectableExcerptCard(excerpt)
                                .frame(maxWidth: .infinity)
                        }

                        if row.count < columnsCount {
                            Spacer(minLength: 0)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .frame(width: availableWidth)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 40).padding(.top, AppPageHeaderMetrics.height + 32).padding(.bottom, 60)
    }

    private func excerptRows(for excerpts: [ExcerptListItem], columnsCount: Int) -> [[ExcerptListItem]] {
        guard columnsCount > 1 else { return excerpts.map { [$0] } }

        var rows: [[ExcerptListItem]] = []
        var pending: [ExcerptListItem] = []

        for excerpt in excerpts {
            if columnSpan(for: excerpt, columnsCount: columnsCount) == columnsCount {
                if !pending.isEmpty {
                    rows.append(pending)
                    pending.removeAll(keepingCapacity: true)
                }
                rows.append([excerpt])
            } else {
                pending.append(excerpt)
                if pending.count == columnsCount {
                    rows.append(pending)
                    pending.removeAll(keepingCapacity: true)
                }
            }
        }

        if !pending.isEmpty {
            rows.append(pending)
        }

        return rows
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
                .stroke(shouldHighlight(excerpt) ? Color.blue : Color.clear, lineWidth: 3)
        )
        .id(excerpt.id)
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

    private func refreshData(animate _: Bool) {
        Task { @MainActor in
            let newData = fetchAndProcessExcerpts()
            
            self.shuffledExcerpts = newData
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

    private func shouldHighlight(_ excerpt: ExcerptListItem) -> Bool {
        (isBatchDeletePresented && selectedExcerptIDs.contains(excerpt.id)) || highlightedExcerptID == excerpt.id
    }

    private func scrollToHighlightedExcerpt(_ id: String?, proxy: ScrollViewProxy) {
        guard let id, shuffledExcerpts.contains(where: { $0.id == id }) else { return }
        DispatchQueue.main.async {
            if displayMode == .artistic {
                withAnimation(.easeOut(duration: 0.22)) {
                    scrolledExcerptID = id
                }
            } else {
                withAnimation(.easeOut(duration: 0.22)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
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
        .appCapsuleStyle(tint: AppColors.readingAmber, fillOpacity: 0.12, strokeOpacity: 0.10)
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
