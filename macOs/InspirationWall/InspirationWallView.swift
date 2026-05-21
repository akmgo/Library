#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

// MARK: - ✨ 灵感画廊 (核心视图)

struct InspirationWallView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedBook: Book?
    @Query private var allExcerpts: [Excerpt]
    @Query private var allBooks: [Book]
    
    @State private var shuffledExcerpts: [ExcerptListItem] = []
    
    @State private var recordToEdit: Excerpt? = nil
    @State private var bookForEdit: Book? = nil
    
    private var annotationFingerprint: String {
        allExcerpts
            .map { "\($0.id)|\($0.type.rawValue)|\($0.createdAt.timeIntervalSince1970)|\($0.content.hashValue)|\($0.book?.id ?? "")" }
            .joined(separator: ";")
    }
    
    private var subtitleText: String {
        "共收集 \(shuffledExcerpts.count) 条内容"
    }
    
    var body: some View {
        let totalExcerptCharacters = shuffledExcerpts.reduce(0) { $0 + $1.content.count }
        let uniqueBooksCount = Set(shuffledExcerpts.map { $0.bookTitle }).count
        let formattedKCount = String(format: "%.1f", Double(totalExcerptCharacters) / 1000.0)
        
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
                    contentID: "\(shuffledExcerpts.count)-\(totalExcerptCharacters)-\(uniqueBooksCount)"
                ) {
                    AppHeaderTitle("灵感碎片", subtitle: subtitleText)
                } trailingContent: {
                    HStack(spacing: 32) {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text(totalExcerptCharacters > 1000 ? formattedKCount : "\(totalExcerptCharacters)").font(.system(size: 32, weight: .heavy, design: .serif)).foregroundColor(.primary)
                                Text(totalExcerptCharacters > 1000 ? "k" : "").font(.system(size: 14, weight: .bold)).foregroundColor(.indigo)
                            }
                            Text("字沉淀").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.secondary.opacity(0.8))
                        }
                        Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 32)
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(uniqueBooksCount)").font(.system(size: 32, weight: .heavy, design: .serif)).foregroundColor(.primary)
                                Text("本").font(.system(size: 14, weight: .bold)).foregroundColor(.orange)
                            }
                            Text("知识源泉").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.secondary.opacity(0.8))
                        }
                    }
                }
            }
            .sheet(item: $recordToEdit) { record in
                ContentEditorSheet(
                    isPresented: Binding(
                        get: { recordToEdit != nil },
                        set: { isPresented in
                            if !isPresented {
                                recordToEdit = nil
                                refreshData(animate: false)
                            }
                        }
                    ),
                    book: bookForEdit,
                    mode: record.isNote ? .note : .excerpt,
                    itemToEdit: record
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
            masonryGrid(containerWidth: containerWidth)
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
                            ExcerptWallCardView(
                                excerpt: excerpt, isMasonry: false,
                                onDelete: deleteExcerpt,
                                onEdit: { s in triggerEdit(for: s) },
                                onLocate: locateBook
                            )
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
                        ExcerptWallCardView(
                            excerpt: excerpt, isMasonry: true,
                            onDelete: deleteExcerpt,
                            onEdit: { s in triggerEdit(for: s) },
                            onLocate: locateBook
                        )
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
}

// MARK: - ✨ 核心数据引擎调度与方法

extension InspirationWallView {
    
    @MainActor
    private func triggerEdit(for excerpt: ExcerptListItem) {
        let targetID = excerpt.id
        if let target = allExcerpts.first(where: { $0.id == targetID }) {
            self.bookForEdit = target.book
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
            type: nil,
            searchText: "",
            sortKey: .newest,
            randomize: true
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
}

#endif
