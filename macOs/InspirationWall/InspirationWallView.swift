#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

// MARK: - 灵感画廊枚举与 DTO 定义

enum InspirationContentType: String, CaseIterable, Identifiable, CustomStringConvertible {
    case all = "全部"; case excerpt = "摘录"; case note = "笔记"
    var id: String { rawValue }
    var description: String { rawValue }
}

enum InspirationSortMode: String, CaseIterable, Identifiable {
    case byBook = "书籍分类"; case random = "随机漫游"
    var id: String { rawValue }
}

// ✨ 核心修改 1：DTO 增加 bookAuthor 字段
struct InspirationSnippet: Identifiable, Hashable {
    let id: String; let content: String; let date: Date; let bookTitle: String; let bookAuthor: String; let bookID: String; let isNote: Bool; let coverData: Data?
}

// MARK: - ✨ 灵感画廊 (核心视图)

struct InspirationWallView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedBook: Book?
    
    @Binding var contentType: InspirationContentType
    @Binding var sortType: GallerySortType
    @Binding var isRandomRoam: Bool
    @Binding var searchText: String
    @Binding var shuffleTrigger: Int
    @Binding var isBatchEditMode: Bool
    @Binding var selectedSnippetsForBatch: Set<String>
    
    @State private var shuffledSnippets: [InspirationSnippet] = []
    
    @State private var recordToEdit: BookAnnotation? = nil
    @State private var bookForEdit: Book? = nil
    
    @State private var isEntranceAnimated: Bool = false
    
    private var subtitleText: String {
        let count = shuffledSnippets.count
        switch contentType { case .all: return "共收集 \(count) 条内容"; case .excerpt: return "共收集 \(count) 条摘录"; case .note: return "共收集 \(count) 条笔记" }
    }
    
    var body: some View {
        let totalSnippetCharacters = shuffledSnippets.reduce(0) { $0 + $1.content.count }
        let uniqueBooksCount = Set(shuffledSnippets.map { $0.bookTitle }).count
        let formattedKCount = String(format: "%.1f", Double(totalSnippetCharacters) / 1000.0)
        
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack {
                    wallContentView(containerWidth: geo.size.width)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .opacity(isEntranceAnimated ? 1.0 : 0.0)
                        .offset(y: isEntranceAnimated ? 0 : 150)
                        .scaleEffect(isEntranceAnimated ? 1.0 : 0.99, anchor: .center)
                        .animation(.appFluidSpring, value: isEntranceAnimated)
                }
                .frame(maxWidth: .infinity)
            }
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("灵感碎片").font(.system(size: 32, weight: .heavy, design: .rounded)).foregroundColor(.primary)
                            Text(subtitleText).font(.system(size: 15, weight: .medium)).foregroundColor(.secondary)
                        }
                        .opacity(isEntranceAnimated ? 1.0 : 0.0)
                        .offset(x: isEntranceAnimated ? 0 : -200)
                        
                        Spacer()
                        
                        HStack(spacing: 32) {
                            VStack(alignment: .trailing, spacing: 2) {
                                HStack(alignment: .lastTextBaseline, spacing: 4) {
                                    Text(totalSnippetCharacters > 1000 ? formattedKCount : "\(totalSnippetCharacters)").font(.system(size: 32, weight: .heavy, design: .serif)).foregroundColor(.primary)
                                    Text(totalSnippetCharacters > 1000 ? "k" : "").font(.system(size: 14, weight: .bold)).foregroundColor(.indigo)
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
                        .opacity(isEntranceAnimated ? 1.0 : 0.0)
                        .offset(x: isEntranceAnimated ? 0 : 200)
                    }
                    .padding(.horizontal, 40).padding(.top, 40).padding(.bottom, 20)
                    .animation(.appFluidSpring, value: isEntranceAnimated)
                    
                    Divider().background(Color.primary.opacity(0.05))
                }
                .background(Color.clear.background(.ultraThinMaterial).opacity(0.85))
                .ignoresSafeArea(edges: .top)
            }
            .overlay(alignment: .bottom) {
                if isBatchEditMode {
                    VStack {
                        Spacer()
                        HStack {
                            Text("已选择 \(selectedSnippetsForBatch.count) 条内容")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                            Button("取消") {
                                withAnimation(.appSnappy) { isBatchEditMode = false; selectedSnippetsForBatch.removeAll() }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            
                            Button(action: deleteSelectedSnippets) {
                                Text("删除选中项")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(selectedSnippetsForBatch.isEmpty ? Color.gray : Color.red)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedSnippetsForBatch.isEmpty)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12).frame(width: 400)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
                        .background(.ultraThinMaterial).clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 20, y: 10).padding(.bottom, 30)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity).animation(.appSnappy))
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
                isEntranceAnimated = false
                refreshData(animate: false)
            }
            .onChange(of: contentType) { _, _ in refreshData(animate: true) }
            .onChange(of: sortType) { _, _ in refreshData(animate: true) }
            .onChange(of: isRandomRoam) { _, _ in refreshData(animate: true) }
            .onChange(of: searchText) { _, _ in refreshData(animate: true) }
            .onChange(of: shuffleTrigger) { _, _ in withAnimation(.appFluidSpring) { shuffledSnippets.shuffle() } }
            .onReceive(NotificationCenter.default.publisher(for: .libraryDidUpdate)) { _ in refreshData(animate: true) }
        }
    }
    
    @ViewBuilder
    private func wallContentView(containerWidth: CGFloat) -> some View {
        if shuffledSnippets.isEmpty {
            ContentUnavailableView { Label("空空如也", systemImage: searchText.isEmpty ? "leaf" : "magnifyingglass") } description: { Text(searchText.isEmpty ? "多读书，多记录，这里会长出智慧的森林。" : "尝试更换搜索关键词。") }
                .padding(.top, 200)
        } else {
            if isRandomRoam == false {
                groupedCatalogView(containerWidth: containerWidth)
            } else {
                masonryGrid(containerWidth: containerWidth)
            }
        }
    }

    private func groupedCatalogView(containerWidth: CGFloat) -> some View {
        LazyVStack(spacing: 60) {
            let grouped = Dictionary(grouping: shuffledSnippets, by: { $0.bookTitle })
            let sortedKeys = grouped.keys.sorted()
            
            ForEach(sortedKeys, id: \.self) { bookTitle in
                let snippets = grouped[bookTitle]!
                HStack(alignment: .top, spacing: 40) {
                    VStack(alignment: .leading, spacing: 16) {
                        if let coverData = snippets.first?.coverData {
                            BookCoverView(coverID: snippets.first?.bookID ?? "", coverData: coverData, fallbackTitle: bookTitle)
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
                            
                            Text(snippets.first?.bookAuthor ?? "佚名")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Text("\(snippets.count) 条灵感")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1)).clipShape(Capsule())
                                .padding(.top, 4) // 增加呼吸感
                        }
                    }.frame(width: 140)
                    
                    LazyVStack(spacing: 16) {
                        ForEach(snippets) { snippet in
                            SnippetCardView(
                                snippet: snippet, isMasonry: false, isBatchEditMode: isBatchEditMode,
                                selectedSnippetsForBatch: $selectedSnippetsForBatch,
                                onDelete: deleteSnippet,
                                onEdit: { s in triggerEdit(for: s) },
                                onLocate: locateBook
                            )
                            .transition(.appCardGlide)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 40).padding(.top, 160).padding(.bottom, 60)
    }
    
    @ViewBuilder
    private func masonryGrid(containerWidth: CGFloat) -> some View {
        let minColumnWidth: CGFloat = 280
        let spacing: CGFloat = 20
        let horizontalPadding: CGFloat = 80
        let availableWidth = max(minColumnWidth, containerWidth - horizontalPadding)
        let columnsCount = max(1, Int((availableWidth + spacing) / (minColumnWidth + spacing)))
        let exactColumnWidth = (availableWidth - spacing * CGFloat(columnsCount - 1)) / CGFloat(columnsCount)
        
        let columns = distributeSnippets(into: columnsCount)
        
        HStack(alignment: .top, spacing: spacing) {
            ForEach(0 ..< columnsCount, id: \.self) { colIndex in
                LazyVStack(spacing: spacing) {
                    ForEach(columns[colIndex]) { snippet in
                        SnippetCardView(
                            snippet: snippet, isMasonry: true, isBatchEditMode: isBatchEditMode,
                            selectedSnippetsForBatch: $selectedSnippetsForBatch,
                            onDelete: deleteSnippet,
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
        .padding(.horizontal, 40).padding(.top, 160).padding(.bottom, 60)
    }
    
    private func distributeSnippets(into columnsCount: Int) -> [[InspirationSnippet]] {
        var columns: [[InspirationSnippet]] = Array(repeating: [], count: columnsCount)
        var columnHeights: [Double] = Array(repeating: 0, count: columnsCount)
        for snippet in shuffledSnippets {
            let approxHeight = 80.0 + Double(snippet.content.count) * 0.8
            let minIndex = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columns[minIndex].append(snippet)
            columnHeights[minIndex] += approxHeight
        }
        return columns
    }
}

// MARK: - ✨ 核心数据引擎调度与方法

extension InspirationWallView {
    
    @MainActor
    private func triggerEdit(for snippet: InspirationSnippet) {
        let targetID = snippet.id
        if let target = try? modelContext.fetch(FetchDescriptor<BookAnnotation>(predicate: #Predicate { $0.id == targetID })).first {
            self.bookForEdit = target.book
            self.recordToEdit = target
        }
    }

    private func refreshData(animate: Bool) {
        Task { @MainActor in
            let newData = fetchAndProcessSnippets()
            
            if animate && self.isEntranceAnimated {
                withAnimation(.appFluidSpring) { self.shuffledSnippets = newData }
            } else {
                self.shuffledSnippets = newData
            }
            
            if !self.isEntranceAnimated {
                try? await Task.sleep(nanoseconds: 80000000)
                withAnimation(.appFluidSpring) {
                    self.isEntranceAnimated = true
                }
            }
        }
    }
    
    @MainActor
    private func fetchAndProcessSnippets() -> [InspirationSnippet] {
        var results: [InspirationSnippet] = []
        let lowerSearch = searchText.lowercased()
        
        let allAnnotations = (try? modelContext.fetch(FetchDescriptor<BookAnnotation>())) ?? []
        
        for a in allAnnotations {
            if contentType == .excerpt && a.type != .excerpt { continue }
            if contentType == .note && a.type != .note { continue }
            
            let safeTitle = a.book?.title ?? "未知书籍"
            // ✨ 核心修改 3：抓取作者信息
            let safeAuthor = a.book?.author ?? "佚名"
            
            if !searchText.isEmpty {
                guard a.content.lowercased().contains(lowerSearch) || safeTitle.lowercased().contains(lowerSearch) else { continue }
            }
            
            // 注入 DTO
            results.append(InspirationSnippet(id: a.id, content: a.content, date: a.createdAt, bookTitle: safeTitle, bookAuthor: safeAuthor, bookID: a.book?.id ?? "", isNote: a.isNote, coverData: a.book?.coverData))
        }
        
        switch sortType {
        case .newest: results.sort(by: { $0.date > $1.date })
        case .oldest: results.sort(by: { $0.date < $1.date })
        case .titleAsc: results.sort(by: { $0.bookTitle < $1.bookTitle })
        }
        
        if isRandomRoam { results.shuffle() }
        return results
    }
    
    @MainActor
    private func deleteSnippet(snippet: InspirationSnippet) {
        let targetID = snippet.id
        if let target = try? modelContext.fetch(FetchDescriptor<BookAnnotation>(predicate: #Predicate { $0.id == targetID })).first {
            modelContext.delete(target)
        }
        try? modelContext.save()
        refreshData(animate: true)
    }
    
    @MainActor
    private func deleteSelectedSnippets() {
        for targetID in selectedSnippetsForBatch {
            if let target = try? modelContext.fetch(FetchDescriptor<BookAnnotation>(predicate: #Predicate { $0.id == targetID })).first {
                modelContext.delete(target)
            }
        }
        try? modelContext.save()
        withAnimation(.appSnappy) { isBatchEditMode = false; selectedSnippetsForBatch.removeAll() }
        refreshData(animate: true)
    }
    
    @MainActor
    private func locateBook(snippet: InspirationSnippet) {
        let targetID = snippet.bookID
        if let book = try? modelContext.fetch(FetchDescriptor<Book>(predicate: #Predicate { $0.id == targetID })).first {
            withAnimation(.appFluidSpring) { selectedBook = book }
        }
    }
}
#endif
