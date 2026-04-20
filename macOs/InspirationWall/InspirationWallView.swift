#if os(macOS)
import SwiftData
import SwiftUI

// MARK: - ✨ 灵感画廊 (文字雨滴与知识脉络版)

/// macOS 端的灵感片段与笔记大盘视图。
///
/// **视觉交互设计：**
/// 该页面采用了与主页一致的底层氛围光系统。
/// 它提供两种迥异的视图模式：
/// 1. `byBook` 模式下，它是一个严谨的图书馆档案抽屉，按书名将零散的知识点串联起来。
/// 2. `random` 模式下，它化身为一张无界的灵感灵感墙，打破书籍的边界，通过智能计算的多列瀑布流 (`Masonry Grid`) 将不同维度的知识碎片进行随机碰撞。
struct InspirationWallView: View {
    @Query var allExcerpts: [Excerpt]
    @Query var allNotes: [Note]
    
    /// 当前用户选择的过滤模式（仅摘录/仅笔记/全部）
    @State private var contentType: InspirationContentType = .all
    /// 当前用户选择的排版模式（分组列表/瀑布流）
    @State private var sortMode: InspirationSortMode = .random
    
    /// 用于触发 `random` 模式下手动重新洗牌的驱动种子。
    @State private var shuffleTrigger: Int = 0
    /// 最终提供给 View 层进行实体渲染的统一直装数据源。
    @State private var shuffledSnippets: [InspirationSnippet] = []
    
    /// 基于当前筛选类型生成的动态子标题文案。
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
    
    // MARK: - 📚 布局组件：档案馆级分组视图 (按书本分类)

    @ViewBuilder
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
                    ForEach(columns[colIndex]) { snippet in MasonrySnippetCardView(snippet: snippet) }
                }
                .frame(width: exactColumnWidth)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 40).padding(.top, 160).padding(.bottom, 60)
    }
    
    // MARK: - 数据引擎

    /// 从 SwiftData 中提取符合当前筛选项的 `Excerpt` 与 `Note` 实体，并转化为无状态的 DTO 集合。
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

    /// 触发重新抓取数据并通过 `.shuffled()` 算法进行全局乱序洗牌。
    private func shuffleData() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { shuffledSnippets = currentSnippets().shuffled() }
    }

    /// 瀑布流列高度均衡分配算法。
    ///
    /// 遍历所有灵感碎片，通过预估字体大小和行高，计算单张卡片理论所需的高度，
    /// 并将其分配给当前高度累加值最小的一列，确保瀑布流在视觉上呈现完美的底边参差状态。
    ///
    /// - Parameter columnsCount: 屏幕动态计算出的容器可用列数。
    /// - Returns: 分发完毕的二维数组。
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
#endif
