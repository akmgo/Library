#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 🌊 灵感画廊 (iOS 高定主页)

/// 聚合展示散落在各本书籍内的思考与金句的核心漫游视图。
///
/// **架构特性：**
/// 该视图采用了自定义的 `Color(uiColor: .systemGroupedBackground)` 打底，并植入了 macOS 同款的弥散星空氛围光。
/// 提供顶部高规格的数据统筹面板（`MobileInspirationStatsHeader`），
/// 根据 `sortMode` 智能切换长列表 (`groupedCatalogView`) 或瀑布流 (`masonryGrid`) 渲染逻辑。
struct MobileInspirationWallView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Query var allExcerpts: [Excerpt]
    @Query var allNotes: [Note]
    
    @State private var contentType: MobileInspirationType = .all
    @State private var sortMode: MobileInspirationSort = .random
    
    /// 当处于随机漫游模式时，驱动数组重新洗牌 (`.shuffled()`) 的状态锚点。
    @State private var shuffleTrigger: Int = 0
    /// 供下层视图实际消费的扁平化数据池。
    @State private var shuffledSnippets: [MobileInspirationSnippet] = []
    
    var isLandscape: Bool { verticalSizeClass == .compact }
    
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
        
        NavigationStack {
            ZStack(alignment: .top) {
                // ================= 1. 统一氛围感环境背景 =================
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                                
                // 引入 macOS 同款星云氛围光
                Circle()
                    .fill(Color.indigo.opacity(0.12))
                    .blur(radius: 80)
                    .frame(width: 300, height: 300)
                    .offset(x: -100, y: -150)
                    .ignoresSafeArea()
                                
                // ================= 2. 底层滚动内容区 =================
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // ✨ 顶部插入高定排版数据看板
                        MobileInspirationStatsHeader(
                            totalSnippets: shuffledSnippets.count,
                            totalCharacters: totalCharacters,
                            uniqueBooksCount: uniqueBooksCount
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                                                
                        if shuffledSnippets.isEmpty {
                            ContentUnavailableView("灵感枯竭", systemImage: "leaf", description: Text("多读书，多记录，这里会长出智慧的森林。"))
                                .padding(.top, 60)
                        } else {
                            if sortMode == .byBook {
                                groupedCatalogView
                            } else {
                                masonryGrid
                            }
                        }
                    }
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("灵感碎片")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Section(header: Text("内容筛选")) {
                            Picker("内容", selection: $contentType) {
                                ForEach(MobileInspirationType.allCases, id: \.self) { type in Text(type.rawValue).tag(type) }
                            }
                        }
                        Section(header: Text("布局模式")) {
                            Picker("布局", selection: $sortMode) {
                                ForEach(MobileInspirationSort.allCases, id: \.self) { mode in Text(mode.rawValue).tag(mode) }
                            }
                        }
                        if sortMode == .random {
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light); impact.impactOccurred()
                                shuffleTrigger += 1
                            }) {
                                Label("重新洗牌", systemImage: "shuffle")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                }
            }
            .onChange(of: contentType) { _, _ in shuffleData() }
            .onChange(of: sortMode) { _, _ in if sortMode == .random { shuffleData() } }
            .onChange(of: shuffleTrigger) { _, _ in shuffleData() }
            .onAppear { shuffleData() }
        }
    }
    
    // MARK: - 📚 布局组件：档案馆级分组视图 (按书本分类)
    
    private var groupedCatalogView: some View {
        LazyVStack(spacing: 32) {
            let grouped = Dictionary(grouping: shuffledSnippets, by: { $0.bookTitle })
            let sortedKeys = grouped.keys.sorted()
            
            ForEach(sortedKeys, id: \.self) { bookTitle in
                let snippets = grouped[bookTitle]!
                let firstSnippet = snippets.first
                
                VStack(alignment: .leading, spacing: 16) {
                    // iOS 专属的分组头部：横向排列封面与标题
                    HStack(spacing: 12) {
                        if let coverData = firstSnippet?.coverData {
                            LocalCoverView(coverData: coverData, fallbackTitle: bookTitle)
                                .frame(width: 48, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                        } else {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(width: 48, height: 72)
                        }
                                                
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bookTitle)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("\(snippets.count) 条灵感")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                                        
                    // 卡片列表
                    LazyVStack(spacing: 16) {
                        ForEach(snippets) { snippet in
                            MobileGroupedSnippetCardView(snippet: snippet)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    // MARK: - 🌊 布局组件：动态自适应瀑布流 (随机漫游)
    
    private var masonryGrid: some View {
        // ✨ 竖屏 1 列，横屏 2 列自适应响应计算
        let columnCount = isLandscape ? 2 : 1
        let cols = masonryColumns(count: columnCount)
        
        return HStack(alignment: .top, spacing: 16) {
            ForEach(0..<columnCount, id: \.self) { colIndex in
                LazyVStack(spacing: 16) {
                    ForEach(cols[colIndex]) { snippet in
                        MobileMasonrySnippetCardView(snippet: snippet)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - 底层数据与映射引擎
    
    /// 将异构的原生 `Excerpt` 与 `Note` 并集组装为抽象的 `MobileInspirationSnippet`。
    private func currentSnippets() -> [MobileInspirationSnippet] {
        var results: [MobileInspirationSnippet] = []
        if contentType == .all || contentType == .excerpt {
            results.append(contentsOf: allExcerpts.map { MobileInspirationSnippet(content: $0.content ?? "", date: $0.createdAt ?? Date(), bookTitle: $0.book?.title ?? "未知书籍", isNote: false, coverData: $0.book?.coverData) })
        }
        if contentType == .all || contentType == .note {
            results.append(contentsOf: allNotes.map { MobileInspirationSnippet(content: $0.content ?? "", date: $0.createdAt ?? Date(), bookTitle: $0.book?.title ?? "未知书籍", isNote: true, coverData: $0.book?.coverData) })
        }
        return results.sorted(by: { $0.date > $1.date })
    }

    /// 执行数据洗牌并利用动画更新 UI。
    private func shuffleData() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { shuffledSnippets = currentSnippets().shuffled() }
    }

    /// 计算瀑布流的网格填充逻辑。
    /// 遍历所有混排后的项，依次填入空缺的瀑布流列槽中。
    private func masonryColumns(count: Int) -> [[MobileInspirationSnippet]] {
        var columns: [[MobileInspirationSnippet]] = Array(repeating: [], count: count)
        for (index, snippet) in shuffledSnippets.enumerated() { columns[index % count].append(snippet) }
        return columns
    }
}
#endif
