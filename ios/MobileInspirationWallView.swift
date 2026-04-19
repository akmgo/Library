#if os(iOS)
import SwiftData
import SwiftUI

enum MobileInspirationType: String, CaseIterable { case all = "全部", excerpt = "摘录", note = "笔记" }
enum MobileInspirationSort: String, CaseIterable { case byBook = "书籍分类", random = "随机漫游" }

// ✨ 升级 1：模型对齐 macOS，加入 coverData 支持封面显示
struct MobileInspirationSnippet: Identifiable, Hashable {
    let id = UUID()
    let content: String
    let date: Date
    let bookTitle: String
    let isNote: Bool
    let coverData: Data?
}

// MARK: - 🌊 灵感画廊 (iOS 高定版)
struct MobileInspirationWallView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Query var allExcerpts: [Excerpt]
    @Query var allNotes: [Note]
    
    @State private var contentType: MobileInspirationType = .all
    @State private var sortMode: MobileInspirationSort = .random
    @State private var shuffleTrigger: Int = 0
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
                        // ✨ 升级 2：顶部插入高定排版数据看板
                        MobileInspirationStatsHeader(
                            totalSnippets: shuffledSnippets.count,
                            totalCharacters: shuffledSnippets.reduce(0) { $0 + $1.content.count },
                            uniqueBooksCount: Set(shuffledSnippets.map { $0.bookTitle }).count
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
        // ✨ 升级 3：竖屏 1 列，横屏 2 列！
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
    
    // MARK: - 数据引擎
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

    private func shuffleData() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { shuffledSnippets = currentSnippets().shuffled() }
    }

    private func masonryColumns(count: Int) -> [[MobileInspirationSnippet]] {
        var columns: [[MobileInspirationSnippet]] = Array(repeating: [], count: count)
        for (index, snippet) in shuffledSnippets.enumerated() { columns[index % count].append(snippet) }
        return columns
    }
}

// MARK: - ✨ 高级数据看板 Header (iOS 专属适配版)
private struct MobileInspirationStatsHeader: View {
    let totalSnippets: Int
    let totalCharacters: Int
    let uniqueBooksCount: Int
    
    var body: some View {
        let formattedKCount = String(format: "%.1f", Double(totalCharacters) / 1000.0)
        
        HStack(spacing: 0) {
            // 数据 1：总字数
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(totalCharacters > 1000 ? formattedKCount : "\(totalCharacters)")
                        .font(.system(size: 28, weight: .heavy, design: .serif))
                        .foregroundColor(.primary)
                    Text(totalCharacters > 1000 ? "k" : "")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.indigo)
                }
                Text("字沉淀").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 32)
            
            // 数据 2：书籍广度
            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(uniqueBooksCount)")
                        .font(.system(size: 28, weight: .heavy, design: .serif))
                        .foregroundColor(.primary)
                    Text("本").font(.system(size: 14, weight: .bold)).foregroundColor(.orange)
                }
                Text("知识源泉").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.8).background(.ultraThinMaterial))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - 子组件：纯净扁平版宽卡片 (书籍分类视图用)
private struct MobileGroupedSnippetCardView: View {
    let snippet: MobileInspirationSnippet
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Image(systemName: snippet.isNote ? "quote.opening" : "text.quote")
                    .font(.system(size: 16))
                    .foregroundColor((snippet.isNote ? Color.orange : Color.indigo).opacity(0.8))
                Spacer()
                Text(snippet.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.trailing, 4)
                Text(snippet.isNote ? "思考" : "摘录")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(snippet.isNote ? .orange : .indigo)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((snippet.isNote ? Color.orange : Color.indigo).opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Text(LocalizedStringKey(snippet.content))
                .font(.system(size: 15, weight: .regular, design: .serif))
                .lineSpacing(6)
                .foregroundColor(.primary.opacity(0.9))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 3)
    }
}

// MARK: - 子组件：漫游版卡片 (带有微型封面，完美复刻 macOS)
private struct MobileMasonrySnippetCardView: View {
    let snippet: MobileInspirationSnippet
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Image(systemName: snippet.isNote ? "quote.opening" : "text.quote")
                    .font(.system(size: 20))
                    .foregroundColor((snippet.isNote ? Color.orange : Color.indigo).opacity(0.8))
                Spacer()
                Text(snippet.isNote ? "思考" : "摘录")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(snippet.isNote ? .orange : .indigo)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((snippet.isNote ? Color.orange : Color.indigo).opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Text(LocalizedStringKey(snippet.content))
                .font(.system(size: 15, weight: .regular, design: .serif))
                .lineSpacing(6)
                .foregroundColor(.primary.opacity(0.9))
                .lineLimit(12)
            
            Divider().opacity(0.5)
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("《\(snippet.bookTitle)》")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(snippet.date.formatted(date: .numeric, time: .omitted))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                // ✨ 完美移植 macOS 的微缩封面设计
                if let coverData = snippet.coverData {
                    LocalCoverView(coverData: coverData, fallbackTitle: snippet.bookTitle)
                        .frame(width: 32, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .shadow(color: Color.black.opacity(0.1), radius: 3, y: 1)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
    }
}
#endif
