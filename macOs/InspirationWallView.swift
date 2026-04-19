#if os(macOS)
import SwiftData
import SwiftUI

enum InspirationContentType: String, CaseIterable { case all = "全部", excerpt = "摘录", note = "笔记" }
enum InspirationSortMode: String, CaseIterable { case byBook = "书籍分类", random = "随机漫游" }

struct InspirationSnippet: Identifiable, Hashable {
    let id = UUID()
    let content: String
    let date: Date
    let bookTitle: String
    let isNote: Bool
    let coverData: Data?
}

// MARK: - ✨ 灵感画廊 (文字雨滴与知识脉络版)

struct InspirationWallView: View {
    @Query var allExcerpts: [Excerpt]
    @Query var allNotes: [Note]
    
    @State private var contentType: InspirationContentType = .all
    @State private var sortMode: InspirationSortMode = .random
    @State private var shuffleTrigger: Int = 0
    @State private var shuffledSnippets: [InspirationSnippet] = []
    
    private var subtitleText: String {
        let count = shuffledSnippets.count
        switch contentType {
        case .all: return "共收集 \(count) 条内容"
        case .excerpt: return "共收集 \(count) 条摘录"
        case .note: return "共收集 \(count) 条笔记"
        }
    }
    
    var body: some View {
        // 计算排版所需的宏观数据
        let totalCharacters = shuffledSnippets.reduce(0) { $0 + $1.content.count }
        let uniqueBooksCount = Set(shuffledSnippets.map { $0.bookTitle }).count
        let formattedKCount = String(format: "%.1f", Double(totalCharacters) / 1000.0)
        
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // ================= 1. 统一氛围感环境背景 =================
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
                                            
                Circle()
                    .fill(Color.indigo.opacity(0.08))
                    .blur(radius: 120)
                    .frame(width: 800, height: 800)
                    .offset(x: -200, y: -300)
                
                // ================= 2. 底层滚动内容区 =================
                ScrollView(.vertical, showsIndicators: false) {
                    if shuffledSnippets.isEmpty {
                        ContentUnavailableView("空空如也", systemImage: "leaf", description: Text("多读书，多记录，这里会长出智慧的森林。"))
                            .padding(.top, 200)
                    } else {
                        if sortMode == .byBook {
                            groupedCatalogView(containerWidth: geo.size.width)
                        } else {
                            masonryGrid(containerWidth: geo.size.width)
                        }
                    }
                }
                
                // ================= 3. ✨ 顶层悬浮高定玻璃 Header =================
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        // 左侧：标题
                        VStack(alignment: .leading, spacing: 8) {
                            Text("灵感碎片")
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)
                            Text(subtitleText)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 右侧：极致 Typography 排版的数据
                        HStack(spacing: 32) {
                            // 数据 1：总字数（强调厚度，使用衬线体拉升文艺感）
                            VStack(alignment: .trailing, spacing: 2) {
                                HStack(alignment: .lastTextBaseline, spacing: 4) {
                                    Text(totalCharacters > 1000 ? formattedKCount : "\(totalCharacters)")
                                        .font(.system(size: 32, weight: .heavy, design: .serif))
                                        .foregroundColor(.primary)
                                    Text(totalCharacters > 1000 ? "k" : "")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.indigo)
                                }
                                Text("字沉淀").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.secondary.opacity(0.8))
                            }
                            
                            // 极简分割线
                            Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 32)
                            
                            // 数据 2：书籍广度（强调涉猎）
                            VStack(alignment: .trailing, spacing: 2) {
                                HStack(alignment: .lastTextBaseline, spacing: 4) {
                                    Text("\(uniqueBooksCount)")
                                        .font(.system(size: 32, weight: .heavy, design: .serif))
                                        .foregroundColor(.primary)
                                    Text("本").font(.system(size: 14, weight: .bold)).foregroundColor(.orange)
                                }
                                Text("知识源泉").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.secondary.opacity(0.8))
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 45) // 与其他模块完全对齐
                    .padding(.bottom, 20)
                    
                    Divider().background(Color.primary.opacity(0.05))
                }
                .background(
                    Color.clear
                        .background(.ultraThinMaterial)
                        .opacity(0.85)
                )
                .ignoresSafeArea(edges: .top)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button(action: { contentType = .all }) { HStack { Text("全部"); if contentType == .all { Image(systemName: "checkmark") } } }
                    Button(action: { contentType = .excerpt }) { HStack { Text("摘录"); if contentType == .excerpt { Image(systemName: "checkmark") } } }
                    Button(action: { contentType = .note }) { HStack { Text("笔记"); if contentType == .note { Image(systemName: "checkmark") } } }
                } label: {
                    Image(systemName: contentType == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                        .foregroundColor(contentType == .all ? .primary : .accentColor)
                }
                .menuIndicator(.hidden).help("筛选内容")
                                        
                Menu {
                    Button(action: { sortMode = .byBook }) { HStack { Text("书籍分类"); if sortMode == .byBook { Image(systemName: "checkmark") } } }
                    Button(action: { sortMode = .random; shuffleTrigger += 1 }) { HStack { Text("随机漫游"); if sortMode == .random { Image(systemName: "checkmark") } } }
                } label: {
                    Image(systemName: sortMode == .random ? "shuffle.circle.fill" : "folder.circle.fill")
                        .foregroundColor(sortMode == .random ? .blue : .primary)
                }
                .menuIndicator(.hidden).help("漫游模式")
            }
        }
        .onChange(of: contentType) { _, _ in shuffleData() }
        .onChange(of: sortMode) { _, _ in if sortMode == .random { shuffleData() } }
        .onChange(of: shuffleTrigger) { _, _ in shuffleData() }
        .onAppear { shuffleData() }
    }
    
    // MARK: - 📚 布局组件：档案馆级分组视图 (按书本分类，单列撑满卡片)

    private func groupedCatalogView(containerWidth: CGFloat) -> some View {
        LazyVStack(spacing: 60) {
            let grouped = Dictionary(grouping: currentSnippets(), by: { $0.bookTitle })
            let sortedKeys = grouped.keys.sorted()
            
            ForEach(sortedKeys, id: \.self) { bookTitle in
                let snippets = grouped[bookTitle]!
                let firstSnippet = snippets.first
                
                HStack(alignment: .top, spacing: 40) {
                    // 左侧：书籍视觉锚点
                    VStack(alignment: .leading, spacing: 16) {
                        if let coverData = firstSnippet?.coverData {
                            LocalCoverView(coverData: coverData, fallbackTitle: bookTitle)
                                .frame(width: 140, height: 210)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
                        } else {
                            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.secondary.opacity(0.1)).frame(width: 140, height: 210)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(bookTitle).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                            Text("\(snippets.count) 条灵感").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary).padding(.horizontal, 8).padding(.vertical, 4).background(Color.secondary.opacity(0.1)).clipShape(Capsule())
                        }
                    }
                    .frame(width: 140)
                    
                    // 右侧：自适应宽度撑满的扁卡片列表
                    LazyVStack(spacing: 16) {
                        ForEach(snippets) { snippet in GroupedSnippetCardView(snippet: snippet) }
                    }
                }
            }
        }
        .padding(.horizontal, 40).padding(.top, 160).padding(.bottom, 60)
    }
    
    // MARK: - 🌊 布局组件：动态自适应瀑布流 (随机漫游)

    private func masonryGrid(containerWidth: CGFloat) -> some View {
        let minColumnWidth: CGFloat = 280
        let spacing: CGFloat = 20
        let horizontalPadding: CGFloat = 80
        let availableWidth = max(minColumnWidth, containerWidth - horizontalPadding)
        
        let columnsCount = max(1, Int((availableWidth + spacing) / (minColumnWidth + spacing)))
        let exactColumnWidth = (availableWidth - spacing * CGFloat(columnsCount - 1)) / CGFloat(columnsCount)
        let columns = distributeSnippets(into: columnsCount)
        
        return HStack(alignment: .top, spacing: spacing) {
            ForEach(0 ..< columnsCount, id: \.self) { colIndex in
                LazyVStack(spacing: spacing) {
                    ForEach(columns[colIndex]) { snippet in MasonrySnippetCardView(snippet: snippet) }
                }
                .frame(width: exactColumnWidth)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 40).padding(.top, 160).padding(.bottom, 60)
    }
    
    // MARK: - 数据引擎

    private func currentSnippets() -> [InspirationSnippet] {
        var results: [InspirationSnippet] = []
        if contentType == .all || contentType == .excerpt {
            results.append(contentsOf: allExcerpts.map { InspirationSnippet(content: $0.content ?? "", date: $0.createdAt ?? Date(), bookTitle: $0.book?.title ?? "未知书籍", isNote: false, coverData: $0.book?.coverData) })
        }
        if contentType == .all || contentType == .note {
            results.append(contentsOf: allNotes.map { InspirationSnippet(content: $0.content ?? "", date: $0.createdAt ?? Date(), bookTitle: $0.book?.title ?? "未知书籍", isNote: true, coverData: $0.book?.coverData) })
        }
        return results.sorted(by: { $0.date > $1.date })
    }

    private func shuffleData() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { shuffledSnippets = currentSnippets().shuffled() }
    }

    private func distributeSnippets(into columnsCount: Int) -> [[InspirationSnippet]] {
        var columns: [[InspirationSnippet]] = Array(repeating: [], count: columnsCount)
        var columnHeights: [Double] = Array(repeating: 0, count: columnsCount)
        for snippet in shuffledSnippets {
            let approxHeight = 80.0 + Double(snippet.content.count) * 0.8 + (snippet.coverData != nil ? 40.0 : 0.0)
            let minIndex = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columns[minIndex].append(snippet)
            columnHeights[minIndex] += approxHeight
        }
        return columns
    }
}

// MARK: - 子组件：纯净扁平版宽卡片 (专用于书籍分类视图)

private struct GroupedSnippetCardView: View {
    let snippet: InspirationSnippet
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Image(systemName: snippet.isNote ? "quote.opening" : "text.quote").font(.system(size: 16)).foregroundColor((snippet.isNote ? Color.orange : Color.indigo).opacity(0.8))
                Spacer()
                Text(snippet.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary.opacity(0.6)).padding(.trailing, 4)
                Text(snippet.isNote ? "思考" : "摘录").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(snippet.isNote ? .orange : .indigo).padding(.horizontal, 8).padding(.vertical, 3).background((snippet.isNote ? Color.orange : Color.indigo).opacity(0.1)).clipShape(Capsule())
            }
            Text(LocalizedStringKey(snippet.content)).font(.system(size: 14, weight: .medium, design: .serif)).lineSpacing(6).foregroundColor(.primary.opacity(0.9))
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(isHovered ? 0.9 : 0.6).background(.ultraThinMaterial))
        .cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(isHovered ? 0.1 : 0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(isHovered ? 0.06 : 0.02), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        .onHover { h in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isHovered = h }
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - 子组件：漫游版卡片 (带有微型封面)

private struct MasonrySnippetCardView: View {
    let snippet: InspirationSnippet
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Image(systemName: snippet.isNote ? "quote.opening" : "text.quote").font(.system(size: 20)).foregroundColor((snippet.isNote ? Color.orange : Color.indigo).opacity(0.8))
                Spacer()
                Text(snippet.isNote ? "思考" : "摘录").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(snippet.isNote ? .orange : .indigo).padding(.horizontal, 8).padding(.vertical, 3).background((snippet.isNote ? Color.orange : Color.indigo).opacity(0.1)).clipShape(Capsule())
            }
            Text(LocalizedStringKey(snippet.content)).font(.system(size: 14, weight: .medium, design: .serif)).lineSpacing(6).foregroundColor(.primary.opacity(0.9)).lineLimit(12)
            Divider().opacity(0.5)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("《\(snippet.bookTitle)》").font(.system(size: 12, weight: .bold)).foregroundColor(.primary).lineLimit(1)
                    Text(snippet.date.formatted(date: .numeric, time: .omitted)).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                }
                Spacer()
                if let coverData = snippet.coverData {
                    LocalCoverView(coverData: coverData, fallbackTitle: snippet.bookTitle).frame(width: 32, height: 48).clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous)).shadow(color: Color.black.opacity(0.1), radius: 3, y: 1).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                }
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(isHovered ? 0.9 : 0.6).background(.ultraThinMaterial))
        .cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(isHovered ? 0.1 : 0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 12 : 8, y: isHovered ? 6 : 4)
        .onHover { h in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isHovered = h }
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
#endif
