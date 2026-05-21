#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 📏 智能高度探测器 (移动端专属)
struct MobileSnippetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

enum VersesFilterTab: String, CaseIterable, CustomStringConvertible {
    case all = "全部"
    case poetry = "诗歌"
    case lyric = "词曲"
    case prose = "短文"
    case quote = "语录"
    case movie = "台词"
    case web = "拾遗"
    
    var description: String { rawValue }
}

// MARK: - 🎨 1. 日常摘录主视图 (iOS 单列沉浸版 - 自治化)
struct MobileInkGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var allSnippets: [Snippet]
    
    // ✨ 状态内部自治
    @State private var activeCategory: VersesFilterTab = .all
    @State private var searchText: String = "" // 保留用于底层过滤，不提供UI
    @State private var sortType: GallerySortType = .dateAdded
    
    @State private var isBatchEditMode: Bool = false
    @State private var selectedSnippetsForBatch: Set<String> = []
    
    @State private var displaySnippets: [Snippet] = []
    // 扩充：总计 + 6个具体分类
    @State private var statsData: (total: Int, poetry: Int, lyric: Int, prose: Int, quote: Int, movie: Int, web: Int) = (0, 0, 0, 0, 0, 0, 0)
    
    @State private var isEntranceAnimated = false
    @State private var showAddSheet = false
    @State private var editingSnippet: Snippet? = nil
    
    @State private var fullscreenSnippet: Snippet? = nil

    private var snippetFingerprint: String {
        allSnippets
            .map { "\($0.id)|\($0.category.rawValue)|\($0.addedDate.timeIntervalSince1970)|\($0.title.hashValue)|\($0.content.hashValue)" }
            .joined(separator: ";")
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AppColors.primaryBackground(for: colorScheme).ignoresSafeArea()
                
                // ================= 📚 核心内容区 =================
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        
                        // ================= 顶部悬浮头 =================
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("日常摘录").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(.primary)
                                Text(activeCategory == .all ? "共收录 \(statsData.total) 篇摘录" : "筛选：\(displaySnippets.count) 篇 \(activeCategory.rawValue)")
                                    .font(.system(size: 14, weight: .medium)).foregroundColor(.secondary)
                            }
                            
                            // ✨ 单行平铺 6 大分类数据区
                            HStack(spacing: 0) {
                                mobileHeaderStatItem(label: "诗歌", value: "\(statsData.poetry)", color: SnippetCategory.poetry.themeColor)
                                Divider().frame(height: 24).opacity(0.5)
                                mobileHeaderStatItem(label: "词曲", value: "\(statsData.lyric)", color: SnippetCategory.lyric.themeColor)
                                Divider().frame(height: 24).opacity(0.5)
                                mobileHeaderStatItem(label: "短文", value: "\(statsData.prose)", color: SnippetCategory.prose.themeColor)
                                Divider().frame(height: 24).opacity(0.5)
                                mobileHeaderStatItem(label: "语录", value: "\(statsData.quote)", color: SnippetCategory.quote.themeColor)
                                Divider().frame(height: 24).opacity(0.5)
                                mobileHeaderStatItem(label: "台词", value: "\(statsData.movie)", color: SnippetCategory.movie.themeColor)
                                Divider().frame(height: 24).opacity(0.5)
                                mobileHeaderStatItem(label: "拾遗", value: "\(statsData.web)", color: SnippetCategory.web.themeColor)
                            }
                            .padding(.vertical, 14)
                            .background(AppColors.secondaryBackground(for: colorScheme).opacity(0.8).background(AppMaterials.card))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: AppRadius.m).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                        .opacity(isEntranceAnimated ? 1.0 : 0.0)
                        .offset(y: isEntranceAnimated ? 0 : 20)
                        
                        // ================= 瀑布流内容 =================
                        if displaySnippets.isEmpty {
                            EmptyStateView(
                                systemImage: "scroll",
                                title: "未找到墨迹",
                                message: "当前分类下暂无摘录，快去录入第一篇吧",
                                minHeight: 320
                            )
                            .padding(.top, 24)
                            .opacity(isEntranceAnimated ? 1.0 : 0.0)
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(displaySnippets) { snippet in
                                    mobileSnippetCardWrapper(for: snippet)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, isBatchEditMode ? 140 : 80)
                            .opacity(isEntranceAnimated ? 1.0 : 0.0)
                            .offset(y: isEntranceAnimated ? 0 : 60)
                        }
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isEntranceAnimated)
                
                // ================= 底部批处理控制台 =================
                if isBatchEditMode {
                    VStack {
                        Spacer()
                        HStack {
                            Text("已选择 \(selectedSnippetsForBatch.count) 篇")
                                .font(.system(size: 14, weight: .bold)).foregroundColor(.primary)
                            Spacer()
                            Button("取消") {
                                withAnimation(.snappy) { isBatchEditMode = false; selectedSnippetsForBatch.removeAll() }
                            }.buttonStyle(.plain).padding(.horizontal, 8)
                            
                            Button(action: deleteSelectedSnippets) {
                                Text("删除选中项")
                                    .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(selectedSnippetsForBatch.isEmpty ? Color.gray : Color.red)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain).disabled(selectedSnippetsForBatch.isEmpty)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 14)
                        .background(AppColors.secondaryBackground(for: colorScheme).opacity(0.95))
                        .background(AppMaterials.card)
                        .overlay(Rectangle().frame(height: 0.5).foregroundColor(.secondary.opacity(0.2)), alignment: .top)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
                }
                
                // ================= 🌟 沉浸式全屏阅读覆盖层 (调用统一组件) =================
                if let snippet = fullscreenSnippet {
                    MobileUnifiedFullscreenReadingView(payload: createPayload(from: snippet)) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            fullscreenSnippet = nil
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(100)
                }
            }
            .navigationTitle("墨香画卷")
            .navigationBarTitleDisplayMode(.inline)
            
            // ✨ 打平所有操作栏入口
            .toolbar {
                // 左上角：接入独立批量管理接口按钮
                ToolbarItem(placement: .navigationBarLeading) {
                    MobileBatchEditToggleButton(isEditing: $isBatchEditMode)
                }
                
                // 右上角：过滤、排序、添加
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // 1. 排序菜单
                        Menu {
                            Picker("排序", selection: $sortType) {
                                ForEach(GallerySortType.allCases) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .disabled(isBatchEditMode)
                        
                        // 2. 分类过滤菜单
                        Menu {
                            Picker("分类", selection: $activeCategory) {
                                ForEach(VersesFilterTab.allCases, id: \.self) { tab in
                                    Text(tab.rawValue).tag(tab)
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .disabled(isBatchEditMode)
                        
                        // 3. 添加按钮
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showAddSheet = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .disabled(isBatchEditMode)
                    }
                }
            }
            .onAppear { refreshData(animate: false) }
            .onChange(of: activeCategory) { _, _ in refreshData(animate: true) }
            .onChange(of: sortType) { _, _ in refreshData(animate: true) }
            .onChange(of: snippetFingerprint) { _, _ in refreshData(animate: true) }
            .sheet(isPresented: $showAddSheet) { MobileSnippetEditorSheet(isPresented: $showAddSheet) }
            .sheet(item: $editingSnippet) { snippet in
                MobileSnippetEditorSheet(
                    isPresented: Binding(
                        get: { editingSnippet != nil },
                        set: { isPresented in if !isPresented { editingSnippet = nil } }
                    ),
                    snippetToEdit: snippet
                )
            }
        }
    }
    
    // MARK: - 🗂️ 数据适配器 (Mapper)
    private func createPayload(from snippet: Snippet) -> MobileFullscreenPayload {
        let showHeader = [.poetry, .lyric, .prose].contains(snippet.category)
        let authorText = "\(snippet.author)\(snippet.dynasty.isEmpty ? "" : " (\(snippet.dynasty))")"
        let validAuthor = (showHeader && !authorText.trimmingCharacters(in: .whitespaces).isEmpty && snippet.author != "佚名") ? authorText : nil
        
        let footerText: String? = {
            if snippet.category == .quote { return "—— \(snippet.author)" }
            if snippet.category == .movie { return "—— \(snippet.author)（\(snippet.title)）" }
            return nil
        }()
        
        return MobileFullscreenPayload(
            title: showHeader ? snippet.title : nil,
            author: validAuthor,
            content: snippet.content,
            alignment: snippet.category == .poetry ? .center : .leading,
            isIndented: [.lyric, .prose].contains(snippet.category),
            footer: footerText,
            annotation: snippet.annotation.isEmpty ? nil : snippet.annotation
        )
    }
    
    // ✨ 卡片包装器
    @ViewBuilder
    private func mobileSnippetCardWrapper(for snippet: Snippet) -> some View {
        ZStack(alignment: .topLeading) {
            MobileDailySnippetCardView(
                snippet: snippet,
                onEdit: { if !isBatchEditMode { editingSnippet = snippet } },
                onExpand: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        fullscreenSnippet = snippet
                    }
                }
            )
            .opacity(isBatchEditMode && !selectedSnippetsForBatch.contains(snippet.id) ? 0.6 : 1.0)
            .scaleEffect(isBatchEditMode && selectedSnippetsForBatch.contains(snippet.id) ? 0.96 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(selectedSnippetsForBatch.contains(snippet.id) ? Color.blue.opacity(0.8) : Color.clear, lineWidth: 3)
            )
            
            if isBatchEditMode {
                Image(systemName: selectedSnippetsForBatch.contains(snippet.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(selectedSnippetsForBatch.contains(snippet.id) ? .blue : .secondary.opacity(0.4))
                    .padding(16)
                    .background(Circle().fill(AppColors.secondaryBackground(for: colorScheme)).opacity(selectedSnippetsForBatch.contains(snippet.id) ? 1 : 0).padding(16))
                    .allowsHitTesting(false)
            }
        }
        .animation(.snappy, value: isBatchEditMode)
        .animation(.snappy, value: selectedSnippetsForBatch.contains(snippet.id))
        .onTapGesture {
            if isBatchEditMode {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.snappy) {
                    if selectedSnippetsForBatch.contains(snippet.id) {
                        selectedSnippetsForBatch.remove(snippet.id)
                    } else {
                        selectedSnippetsForBatch.insert(snippet.id)
                    }
                }
            } else {
                // 非编辑模式下点击卡片展开全屏
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    fullscreenSnippet = snippet
                }
            }
        }
    }
    
    private func mobileHeaderStatItem(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(color)
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // 数据引擎
    private func refreshData(animate: Bool) {
        Task { @MainActor in
            let snapshot = ReadingStatsCalculator.snippetGallerySnapshot(
                snippets: allSnippets,
                category: activeCategory.snippetCategory,
                searchText: searchText,
                sortKey: sortType.snippetSortKey
            )
            let newStats = snapshot.stats
            let newDisplay = snapshot.snippets
            
            if animate && self.isEntranceAnimated {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    self.statsData = (newStats.total, newStats.poetry, newStats.lyric, newStats.prose, newStats.quote, newStats.movie, newStats.web)
                    self.displaySnippets = newDisplay
                }
            } else {
                self.statsData = (newStats.total, newStats.poetry, newStats.lyric, newStats.prose, newStats.quote, newStats.movie, newStats.web)
                self.displaySnippets = newDisplay
            }
            
            if !self.isEntranceAnimated {
                try? await Task.sleep(nanoseconds: 60_000_000)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    self.isEntranceAnimated = true
                }
            }
        }
    }
    
    private func deleteSelectedSnippets() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        let toDelete = displaySnippets.filter { selectedSnippetsForBatch.contains($0.id) }
        try? ReadingDataService.shared.deleteSnippets(toDelete, context: modelContext)
        withAnimation(.snappy) { isBatchEditMode = false; selectedSnippetsForBatch.removeAll() }
    }
}

extension VersesFilterTab {
    var snippetCategory: SnippetCategory? {
        switch self {
        case .all:
            return nil
        case .poetry:
            return .poetry
        case .lyric:
            return .lyric
        case .prose:
            return .prose
        case .quote:
            return .quote
        case .movie:
            return .movie
        case .web:
            return .web
        }
    }
}

extension GallerySortType {
    var snippetSortKey: SnippetGallerySortKey {
        switch self {
        case .title:
            return .titleAscending
        case .dateAdded, .lastRead, .progress:
            return .newest
        }
    }
}

// MARK: - 🃏 2. 摘录微观卡片 (iOS 适配版)
struct MobileDailySnippetCardView: View {
    let snippet: Snippet
    var onEdit: () -> Void = {}
    var onExpand: () -> Void = {}
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var naturalHeight: CGFloat = 0
    private let maxHeight: CGFloat = 400
    private var isTruncated: Bool { naturalHeight > maxHeight }
    
    private var indentedContent: String {
        snippet.content.components(separatedBy: .newlines).map { "\u{3000}\u{3000}" + $0 }.joined(separator: "\n")
    }
    
    private var titleAndAuthor: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(snippet.title)
                .font(.system(size: 20, weight: .heavy, design: .serif))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            let authorText = "\(snippet.author)\(snippet.dynasty.isEmpty ? "" : " (\(snippet.dynasty))")"
            if !authorText.trimmingCharacters(in: .whitespaces).isEmpty && snippet.author != "佚名" {
                Text(authorText)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 16)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // ================= 📝 核心排版容器 =================
            VStack(alignment: .center, spacing: 0) {
                if [.poetry, .lyric, .prose].contains(snippet.category) {
                    titleAndAuthor
                }
                
                switch snippet.category {
                case .poetry:
                    Text(snippet.content).font(.system(size: 15, weight: .regular, design: .serif)).lineSpacing(10).foregroundColor(.primary.opacity(0.85)).multilineTextAlignment(.center).frame(maxWidth: .infinity, alignment: .center)
                case .lyric, .prose:
                    Text(indentedContent).font(.system(size: 15, weight: .regular, design: .serif)).lineSpacing(10).foregroundColor(.primary.opacity(0.85)).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                case .quote:
                    Text(snippet.content).font(.system(size: 15, weight: .regular, design: .serif)).lineSpacing(10).foregroundColor(.primary.opacity(0.85)).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 16)
                    HStack { Spacer(); Text("—— \(snippet.author)").font(.system(size: 13, weight: .medium, design: .serif)).foregroundColor(.secondary) }
                case .movie:
                    Text(snippet.content).font(.system(size: 15, weight: .regular, design: .serif)).lineSpacing(10).foregroundColor(.primary.opacity(0.85)).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 16)
                    HStack { Spacer(); Text("—— \(snippet.author)（\(snippet.title)）").font(.system(size: 13, weight: .medium, design: .serif)).foregroundColor(.secondary) }
                case .web:
                    Text(snippet.content).font(.system(size: 15, weight: .regular, design: .serif)).lineSpacing(10).foregroundColor(.primary.opacity(0.85)).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            
            // 探测高度
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: MobileSnippetHeightPreferenceKey.self, value: geo.size.height)
                }
            )
            .frame(height: isTruncated ? maxHeight : nil, alignment: .top)
            
            // Alpha 遮罩
            .mask {
                if isTruncated {
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0.0),
                            .init(color: .black, location: 0.75),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                } else { Color.black }
            }
            .clipped()
            
            // ================= 🌟 展开按钮 =================
            if isTruncated {
                Button(action: onExpand) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.backward.and.arrow.down.forward")
                        Text("全屏阅读")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(snippet.category.themeColor.opacity(0.9))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 16)
            }
        }
        .overlay(alignment: .topTrailing) {
            Text(snippet.category.displayName)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(snippet.category.themeColor)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(snippet.category.themeColor.opacity(0.15))
                .clipShape(Capsule())
                .padding([.top, .trailing], 12)
        }
        .onPreferenceChange(MobileSnippetHeightPreferenceKey.self) { h in
            if abs(naturalHeight - h) > 1 { naturalHeight = h }
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppColors.secondaryBackground(for: colorScheme).opacity(0.9))
        )
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
        .contextMenu {
            Button(action: {
                UIPasteboard.general.string = snippet.content
            }) { Label("拷贝内容", systemImage: "doc.on.doc") }
            
            Button(action: onEdit) { Label("编辑内容", systemImage: "pencil") }
        }
    }
}
#endif
