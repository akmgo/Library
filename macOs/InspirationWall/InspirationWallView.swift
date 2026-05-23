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
    @Binding var selectedBook: Book?
    let filterCategory: ExcerptCategory?
    let sortKey: AnnotationSortKey
    let displayMode: ExcerptWallDisplayMode
    @Binding var isBatchDeletePresented: Bool
    @Binding var selectedExcerptIDs: Set<String>
    @Query private var allExcerpts: [Excerpt]
    @Query private var allBooks: [Book]
    
    @State private var shuffledExcerpts: [ExcerptListItem] = []
    
    @State private var recordToEdit: Excerpt? = nil
    
    private var annotationFingerprint: String {
        allExcerpts
            .map { "\($0.id)|\($0.type.rawValue)|\($0.createdAt.timeIntervalSince1970)|\($0.content.hashValue)|\($0.book?.id ?? "")" }
            .joined(separator: ";")
            + "|\(filterCategory?.rawValue ?? "all")|\(sortKey)|\(displayMode)"
    }
    
    var body: some View {
        let totalExcerptCharacters = shuffledExcerpts.reduce(0) { $0 + $1.content.count }
        let uniqueBooksCount = Set(shuffledExcerpts.map { $0.bookTitle }).count
        
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack {
                    wallContentView(containerWidth: geo.size.width)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity)
            }
            .overlay(alignment: .top) {
                AppPageHeader(
                    contentID: "\(shuffledExcerpts.count)-\(totalExcerptCharacters)-\(uniqueBooksCount)-\(filterCategory?.rawValue ?? "all")-\(sortKey)-\(displayMode)"
                ) {
                    AppHeaderTitle("摘录长廊", subtitle: "书中摘录与日常片段汇集于此。")
                } trailingContent: {
                    AppHeaderStatsView(excerptHeaderStats)
                }
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
    private func wallContentView(containerWidth: CGFloat) -> some View {
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
                groupedCatalogView(containerWidth: containerWidth)
            case .artistic:
                masonryGrid(containerWidth: containerWidth)
            }
        }
    }

    private func groupedCatalogView(containerWidth: CGFloat) -> some View {
        LazyVStack(spacing: 60) {
            let grouped = Dictionary(grouping: shuffledExcerpts, by: { $0.bookTitle })
            let sortedKeys = grouped.keys.sorted()
            
            ForEach(sortedKeys, id: \.self) { bookTitle in
                let excerpts = grouped[bookTitle]!
                HStack(alignment: .top, spacing: 40) {
                    VStack(alignment: .leading, spacing: 16) {
                        if let coverData = excerpts.first?.coverData {
                            BookCoverView(coverID: excerpts.first?.bookID ?? "", coverData: coverData, fallbackTitle: bookTitle)
                                .frame(width: 140, height: 210).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
                        } else {
                            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.secondary.opacity(0.1)).frame(width: 140, height: 210)
                        }
                        
                        // ✨ 核心修改 2：书名与作者的上下排版
                        VStack(alignment: .leading, spacing: 6) {
                            Text(bookTitle)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text(excerpts.first?.bookAuthor ?? "佚名")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Text("\(excerpts.count) 条灵感")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1)).clipShape(Capsule())
                                .padding(.top, 4) // 增加呼吸感
                        }
                    }.frame(width: 140)
                    
                    LazyVStack(spacing: 16) {
                        ForEach(excerpts) { excerpt in
                            selectableExcerptCard(excerpt, isMasonry: false)
                            .transition(.appCardGlide)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 40).padding(.top, AppPageHeaderMetrics.height + 32).padding(.bottom, 60)
    }
    
    @ViewBuilder
    private func masonryGrid(containerWidth: CGFloat) -> some View {
        let minColumnWidth: CGFloat = 280
        let spacing: CGFloat = 20
        let horizontalPadding: CGFloat = 80
        let availableWidth = max(minColumnWidth, containerWidth - horizontalPadding)
        let columnsCount = max(1, Int((availableWidth + spacing) / (minColumnWidth + spacing)))
        let exactColumnWidth = (availableWidth - spacing * CGFloat(columnsCount - 1)) / CGFloat(columnsCount)
        
        let columns = distributeExcerpts(into: columnsCount)
        
        HStack(alignment: .top, spacing: spacing) {
            ForEach(0 ..< columnsCount, id: \.self) { colIndex in
                LazyVStack(spacing: spacing) {
                    ForEach(columns[colIndex]) { excerpt in
                        selectableExcerptCard(excerpt, isMasonry: true)
                        .transition(.appCardGlide)
                    }
                }
                .frame(width: exactColumnWidth)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 40).padding(.top, AppPageHeaderMetrics.height + 32).padding(.bottom, 60)
    }
    
    private func distributeExcerpts(into columnsCount: Int) -> [[ExcerptListItem]] {
        var columns: [[ExcerptListItem]] = Array(repeating: [], count: columnsCount)
        var columnHeights: [Double] = Array(repeating: 0, count: columnsCount)
        for excerpt in shuffledExcerpts {
            let approxHeight = 80.0 + Double(excerpt.content.count) * 0.8
            let minIndex = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columns[minIndex].append(excerpt)
            columnHeights[minIndex] += approxHeight
        }
        return columns
    }

    private var excerptHeaderStats: [AppHeaderStatItem] {
        let counts = Dictionary(grouping: allExcerpts, by: \.category).mapValues(\.count)
        return [
            AppHeaderStatItem(allExcerpts.count, label: "全部", unit: "条"),
            AppHeaderStatItem(counts[.bookExcerpt, default: 0], label: ExcerptCategory.bookExcerpt.displayName, unit: "条"),
            AppHeaderStatItem(counts[.note, default: 0], label: ExcerptCategory.note.displayName, unit: "条"),
            AppHeaderStatItem(counts[.poetry, default: 0], label: ExcerptCategory.poetry.displayName, unit: "条"),
            AppHeaderStatItem(counts[.lyric, default: 0], label: ExcerptCategory.lyric.displayName, unit: "条"),
            AppHeaderStatItem(counts[.prose, default: 0], label: ExcerptCategory.prose.displayName, unit: "条"),
            AppHeaderStatItem(counts[.quote, default: 0], label: ExcerptCategory.quote.displayName, unit: "条"),
            AppHeaderStatItem(counts[.web, default: 0], label: ExcerptCategory.web.displayName, unit: "条"),
            AppHeaderStatItem(counts[.movie, default: 0], label: ExcerptCategory.movie.displayName, unit: "条")
        ]
    }

    private func selectableExcerptCard(_ excerpt: ExcerptListItem, isMasonry: Bool) -> some View {
        ExcerptWallCardView(
            excerpt: excerpt,
            isMasonry: isMasonry,
            onDelete: deleteExcerpt,
            onEdit: { item in triggerEdit(for: item) },
            onLocate: { item in
                if isBatchDeletePresented {
                    toggleSelection(for: item)
                } else {
                    locateBook(excerpt: item)
                }
            }
        )
        .overlay(alignment: .topTrailing) {
            if isBatchDeletePresented {
                Image(systemName: selectedExcerptIDs.contains(excerpt.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selectedExcerptIDs.contains(excerpt.id) ? AppColors.readingAmber : Color.secondary)
                    .padding(12)
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
            randomize: displayMode == .artistic
        ).excerpts
    }
    
    @MainActor
    private func deleteExcerpt(excerpt: ExcerptListItem) {
        let targetID = excerpt.id
        if let target = allExcerpts.first(where: { $0.id == targetID }) {
            try? ReadingDataService.shared.deleteExcerpt(target, context: modelContext)
        }
        refreshData(animate: true)
    }
    
    @MainActor
    private func locateBook(excerpt: ExcerptListItem) {
        let targetID = excerpt.bookID
        if let book = allBooks.first(where: { $0.id == targetID }) {
            selectedBook = book
        }
    }

    private func toggleSelection(for excerpt: ExcerptListItem) {
        withAnimation(.appControlFeedback) {
            if selectedExcerptIDs.contains(excerpt.id) {
                selectedExcerptIDs.remove(excerpt.id)
            } else {
                selectedExcerptIDs.insert(excerpt.id)
            }
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
