#if os(macOS)
import SwiftData
import SwiftUI
import AppKit // ✨ 引入 AppKit 以调用触控板底层震动反馈

// MARK: - 🗂️ 模块枚举
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

// MARK: - 📏 智能高度探测器
struct SnippetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - 🧮 1. 核心引擎：自适应跨列瀑布流布局
struct SpanMasonryLayout: Layout {
    var columns: Int = 2
    var spacing: CGFloat = 24
    var spans: [Int]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 1200
        let columnWidth = (width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        var heights = Array(repeating: CGFloat(0), count: columns)

        for (index, subview) in subviews.enumerated() {
            let span = min(max(1, spans.indices.contains(index) ? spans[index] : 1), columns)
            let placement = findPlacement(for: span, in: heights)
            let proposalWidth = columnWidth * CGFloat(span) + spacing * CGFloat(span - 1)
            let size = subview.sizeThatFits(ProposedViewSize(width: proposalWidth, height: nil))

            let newY = placement.y + size.height + spacing
            for i in placement.col..<(placement.col + span) { heights[i] = newY }
        }
        return CGSize(width: width, height: heights.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columnWidth = (bounds.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        var heights = Array(repeating: bounds.minY, count: columns)

        for (index, subview) in subviews.enumerated() {
            let span = min(max(1, spans.indices.contains(index) ? spans[index] : 1), columns)
            let placement = findPlacement(for: span, in: heights)
            
            let x = bounds.minX + CGFloat(placement.col) * (columnWidth + spacing)
            let y = placement.y
            let proposalWidth = columnWidth * CGFloat(span) + spacing * CGFloat(span - 1)
            
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: proposalWidth, height: nil))
            let size = subview.sizeThatFits(ProposedViewSize(width: proposalWidth, height: nil))
            
            let newY = y + size.height + spacing
            for i in placement.col..<(placement.col + span) { heights[i] = newY }
        }
    }

    private func findPlacement(for span: Int, in heights: [CGFloat]) -> (col: Int, y: CGFloat) {
        var bestCol = 0
        var minY = CGFloat.infinity
        for i in 0...(columns - span) {
            let maxYInSpan = heights[i..<(i + span)].max() ?? 0
            if maxYInSpan < minY { minY = maxYInSpan; bestCol = i }
        }
        return (bestCol, minY)
    }
}

// MARK: - 🎨 2. 日常摘录主视图 (Deep Float 加强版动画)
struct InkGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Binding var activeCategory: VersesFilterTab
    @Binding var searchText: String
    @Binding var sortType: GallerySortType
    @Binding var isCarouselMode: Bool
    @Binding var isBatchEditMode: Bool
    @Binding var selectedSnippetsForBatch: Set<String>
    
    @State private var displaySnippets: [Snippet] = []
    @State private var statsData: (total: Int, poetry: Int, prose: Int, quote: Int, movie: Int) = (0, 0, 0, 0, 0)
    
    @State private var isEntranceAnimated = false
    @State private var showAddSheet = false
    @State private var editingSnippet: Snippet? = nil
    
    // ✨ 状态追踪：用于触控板震动
    @State private var scrolledID: PersistentIdentifier?
    // ✨ 状态容器：当前进入全屏阅读的长文
    @State private var fullscreenSnippet: Snippet? = nil
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                
                // ================= 📚 核心内容区 =================
                Group {
                    if displaySnippets.isEmpty {
                        ScrollView {
                            ContentUnavailableView {
                                Label("未找到墨迹", systemImage: "scroll")
                            } description: {
                                Text(searchText.isEmpty ? "当前分类下暂无摘录，快去录入第一篇吧" : "没有找到与“\(searchText)”相关的内容")
                            }
                            .frame(maxWidth: .infinity, minHeight: geo.size.height)
                        }
                    } else {
                        if isCarouselMode {
                            // ✨ 单页横向滑动模式
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 0) {
                                    ForEach(displaySnippets) { snippet in
                                        // 🌟 核心：外层 ZStack 撑满屏幕并上下左右居中对齐，内层卡片自然生长
                                        ZStack(alignment: .center) {
                                            snippetCardWrapper(for: snippet, fixedWidth: 800)
                                                // 滚动过渡物理动效
                                                .scrollTransition(axis: .horizontal) { content, phase in
                                                    content
                                                        .scaleEffect(phase.isIdentity ? 1.0 : 0.85)
                                                        .opacity(phase.isIdentity ? 1.0 : 0.3)
                                                        .offset(y: phase.isIdentity ? 0 : 30)
                                                }
                                        }
                                        .frame(width: geo.size.width, height: geo.size.height)
                                        .id(snippet.id)
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .scrollPosition(id: $scrolledID)
                            .scrollTargetBehavior(.viewAligned) // 🍎 开启原生阻尼吸附
                            .transition(.opacity)
                            .onChange(of: scrolledID) { old, new in
                                // ✨ 触控板马达反馈
                                if new != old && new != nil {
                                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                                }
                            }
                        } else {
                            // ✨ 纵向瀑布流模式
                            ScrollView(.vertical, showsIndicators: true) {
                                let allSpans = displaySnippets.map { $0.category == .prose ? 2 : 1 }
                                SpanMasonryLayout(columns: 2, spacing: 24, spans: allSpans) {
                                    ForEach(displaySnippets) { snippet in
                                        snippetCardWrapper(for: snippet, fixedWidth: nil)
                                    }
                                }
                                .padding(.horizontal, 40).padding(.top, 140)
                                .padding(.bottom, isBatchEditMode ? 140 : 60)
                            }
                            .transition(.opacity)
                        }
                    }
                }
                // ✨✨✨ 核心修复 1：扁平化图层
                // 强制要求 GPU 在离屏缓冲区把卡片画好，然后再一起做 3D 旋转和模糊。这能直接斩断组件内部由于时序错乱导致的闪屏！
                .compositingGroup()
                
                // ✨✨✨ Deep Float 核心修饰符：视觉极限强化
                
                // 1. 深度模糊：略微调低初始模糊强度，减轻 GPU 瞬间压力
                .blur(radius: isEntranceAnimated ? 0 : 10)
                
                // 2. 基础透明度
                .opacity(isEntranceAnimated ? 1.0 : 0.0)
                
                // 3. 尺寸缩放：从更小的尺寸膨胀开来
                .scaleEffect(isEntranceAnimated ? 1.0 : 0.8, anchor: .bottom)
                
                // 4. 垂直位移：从屏幕大半个高度升起
                .offset(y: isEntranceAnimated ? 0 : geo.size.height / 1.8)
                
                // 5. 🌟 3D 视角透视：稍微降低初始旋转角度，防止材质由于大角度形变而黑屏
                .rotation3DEffect(
                    .degrees(isEntranceAnimated ? 0 : 10),
                    axis: (x: 1, y: 0, z: 0), // 绕 X 轴旋转
                    anchor: .bottom, // 以底部为转轴
                    perspective: 0.3 // 增强透视感
                )
                
                // 统一弹簧动画参数
                .animation(.appFluidSpring, value: isEntranceAnimated)
                .animation(.appFluidSpring, value: displaySnippets)
                .animation(.appFluidSpring, value: isCarouselMode)
                
                // ================= 顶部悬浮头 (联动加强) =================
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        // 👈 左侧文字区：戏剧性向右滑入 + 纵向落入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("日常摘录").font(.system(size: 32, weight: .heavy, design: .rounded)).foregroundColor(.primary)
                            Text(activeCategory == .all ? "共收录 \(statsData.total) 篇摘录" : "筛选：\(displaySnippets.count) 篇 \(activeCategory.rawValue)").font(.system(size: 15, weight: .medium)).foregroundColor(.secondary)
                        }
                        .opacity(isEntranceAnimated ? 1.0 : 0.0)
                        // 增加了 Y 轴和 X 轴的位移
                        .offset(x: isEntranceAnimated ? 0 : -300, y: isEntranceAnimated ? 0 : -80)
                        
                        Spacer()
                        
                        // 👉 右侧数据区：戏剧性向左滑入 + 纵向落入
                        HStack(spacing: 16) {
                            headerStatItem(label: "诗词", value: "\(statsData.poetry)", color: SnippetCategory.poetry.themeColor)
                            Divider().frame(height: 30)
                            headerStatItem(label: "短文", value: "\(statsData.prose)", color: SnippetCategory.prose.themeColor)
                            Divider().frame(height: 30)
                            headerStatItem(label: "语录", value: "\(statsData.quote)", color: SnippetCategory.quote.themeColor)
                            Divider().frame(height: 30)
                            headerStatItem(label: "台词", value: "\(statsData.movie)", color: SnippetCategory.movie.themeColor)
                        }
                        .padding(.horizontal, 24).padding(.vertical, 10).background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                        .opacity(isEntranceAnimated ? 1.0 : 0.0)
                        // 增加了 Y 轴和 X 轴的位移
                        .offset(x: isEntranceAnimated ? 0 : 300, y: isEntranceAnimated ? 0 : -80)
                    }
                    .padding(.horizontal, 40).padding(.top, 45).padding(.bottom, 20).animation(.appFluidSpring, value: isEntranceAnimated)
                    Divider().background(Color.primary.opacity(0.05))
                }
                .background(Color.clear.background(.ultraThinMaterial).opacity(0.85))
                .ignoresSafeArea(edges: .top)
                .frame(maxHeight: .infinity, alignment: .top)
                
                // ================= 底部批处理控制台 =================
                if isBatchEditMode {
                    VStack {
                        Spacer()
                        HStack {
                            Text("已选择 \(selectedSnippetsForBatch.count) 篇")
                                .font(.system(size: 14, weight: .bold)).foregroundColor(.primary)
                            Spacer()
                            Button("取消") {
                                withAnimation(.appSnappy) { isBatchEditMode = false; selectedSnippetsForBatch.removeAll() }
                            }.buttonStyle(.plain).padding(.horizontal, 8)
                            
                            Button(action: deleteSelectedSnippets) {
                                Text("删除选中项")
                                    .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                    .padding(.horizontal, 16).padding(.vertical, 6)
                                    .background(selectedSnippetsForBatch.isEmpty ? Color.gray : Color.red)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain).disabled(selectedSnippetsForBatch.isEmpty)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12).frame(width: 400)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
                        .background(.ultraThinMaterial).clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                        .padding(.bottom, 30)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity).animation(.appSnappy))
                    .zIndex(10)
                }
            }
            
            // ================= 🌟 沉浸式全屏阅读覆盖层 =================
            .overlay {
                if let snippet = fullscreenSnippet {
                    SnippetFullscreenReadingView(snippet: snippet) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            fullscreenSnippet = nil
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(100)
                }
            }
        }
        .onAppear {
            refreshData(animate: false)
        }
        .onChange(of: activeCategory) { _, _ in refreshData(animate: true) }
        .onChange(of: searchText) { _, _ in refreshData(animate: true) }
        .onChange(of: sortType) { _, _ in refreshData(animate: true) }
        .onReceive(NotificationCenter.default.publisher(for: .libraryDidUpdate)) { _ in
            refreshData(animate: true)
        }
        .sheet(isPresented: $showAddSheet) { SnippetEditorSheet(isPresented: $showAddSheet) }
        .sheet(item: $editingSnippet) { snippet in
            SnippetEditorSheet(
                isPresented: Binding(
                    get: { editingSnippet != nil },
                    set: { isPresented in if !isPresented { editingSnippet = nil } }
                ),
                snippetToEdit: snippet
            )
        }
    }
    
    // ✨ 卡片包装器
    @ViewBuilder
    private func snippetCardWrapper(for snippet: Snippet, fixedWidth: CGFloat?) -> some View {
        ZStack(alignment: .topLeading) {
            DailySnippetCardView(
                snippet: snippet,
                onEdit: { if !isBatchEditMode { editingSnippet = snippet } },
                onExpand: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        fullscreenSnippet = snippet
                    }
                }
            )
            .opacity(isBatchEditMode && !selectedSnippetsForBatch.contains(snippet.id) ? 0.6 : 1.0)
            .scaleEffect(isBatchEditMode && selectedSnippetsForBatch.contains(snippet.id) ? 0.98 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selectedSnippetsForBatch.contains(snippet.id) ? Color.blue.opacity(0.8) : Color.clear, lineWidth: 3)
            )
            
            if isBatchEditMode {
                Image(systemName: selectedSnippetsForBatch.contains(snippet.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(selectedSnippetsForBatch.contains(snippet.id) ? .blue : .secondary.opacity(0.4))
                    .padding(16)
                    .background(Circle().fill(Color(nsColor: .windowBackgroundColor)).opacity(selectedSnippetsForBatch.contains(snippet.id) ? 1 : 0).padding(16))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: fixedWidth)
        .animation(.appSnappy, value: isBatchEditMode)
        .animation(.appSnappy, value: selectedSnippetsForBatch.contains(snippet.id))
        .onTapGesture {
            if isBatchEditMode {
                withAnimation(.snappy) {
                    if selectedSnippetsForBatch.contains(snippet.id) {
                        selectedSnippetsForBatch.remove(snippet.id)
                    } else {
                        selectedSnippetsForBatch.insert(snippet.id)
                    }
                }
            }
        }
    }
    
    private func headerStatItem(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(color)
        }
    }
    
    private func refreshData(animate: Bool) {
        Task { @MainActor in
            let newStats = fetchStatsData()
            let newDisplay = fetchDisplaySnippets()
            
            if animate && self.isEntranceAnimated {
                withAnimation(.appFluidSpring) {
                    self.statsData = newStats
                    self.displaySnippets = newDisplay
                }
            } else {
                self.statsData = newStats
                self.displaySnippets = newDisplay
            }
            
            // ✨ 终极时序：延长等待确保底层数据被完全排版后，再拉开帷幕，消除残影！
            if !self.isEntranceAnimated {
                try? await Task.sleep(nanoseconds: 60_000_000)
                withAnimation(.appFluidSpring) {
                    self.isEntranceAnimated = true
                }
            }
        }
    }
    
    @MainActor
    private func fetchStatsData() -> (total: Int, poetry: Int, prose: Int, quote: Int, movie: Int) {
        let desc = FetchDescriptor<Snippet>()
        let all = (try? modelContext.fetch(desc)) ?? []
        let poetry = all.filter { $0.category == .poetry || $0.category == .lyric }.count
        let prose = all.filter { $0.category == .prose }.count
        let quote = all.filter { $0.category == .quote }.count
        let movie = all.filter { $0.category == .movie }.count
        return (all.count, poetry, prose, quote, movie)
    }
    
    @MainActor
    private func fetchDisplaySnippets() -> [Snippet] {
        let desc = FetchDescriptor<Snippet>()
        var all = (try? modelContext.fetch(desc)) ?? []
        
        if activeCategory != .all {
            all = all.filter { $0.category.displayName == activeCategory.rawValue }
        }
        
        if !searchText.isEmpty {
            let lower = searchText.lowercased()
            all = all.filter {
                $0.title.lowercased().contains(lower) ||
                $0.author.lowercased().contains(lower) ||
                $0.dynasty.lowercased().contains(lower) ||
                $0.content.lowercased().contains(lower)
            }
        }
        
        switch sortType {
        case .newest: all.sort { $0.addedDate > $1.addedDate }
        case .oldest: all.sort { $0.addedDate < $1.addedDate }
        case .titleAsc: all.sort { $0.title < $1.title }
        }
        return all
    }
    
    private func deleteSelectedSnippets() {
        let toDelete = displaySnippets.filter { selectedSnippetsForBatch.contains($0.id) }
        for snippet in toDelete { modelContext.delete(snippet) }
        try? modelContext.save()
        withAnimation(.appSnappy) { isBatchEditMode = false; selectedSnippetsForBatch.removeAll() }
        NotificationCenter.default.post(name: .libraryDidUpdate, object: nil)
    }
}

// MARK: - 🃏 3. 摘录微观卡片 (智能探测与完美自适应)
struct DailySnippetCardView: View {
    let snippet: Snippet
    var onEdit: () -> Void = {}
    var onExpand: () -> Void = {}
    
    @State private var isHovered = false
    
    // ✨ 记录卡片自然展开的真实物理高度
    @State private var naturalHeight: CGFloat = 0
    
    private let maxHeight: CGFloat = 700
    private var isTruncated: Bool { naturalHeight > maxHeight }
    
    private var indentedContent: String {
        snippet.content.components(separatedBy: .newlines).map { "\u{3000}\u{3000}" + $0 }.joined(separator: "\n")
    }
    
    private var titleAndAuthor: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Spacer()
            Text(snippet.title).font(.system(size: 26, weight: .heavy, design: .serif)).foregroundColor(.primary).multilineTextAlignment(.center)
            Text("").frame(width: 0).overlay(alignment: .bottomLeading) {
                let authorText = "\(snippet.author)\(snippet.dynasty.isEmpty ? "" : " (\(snippet.dynasty))")"
                if !authorText.trimmingCharacters(in: .whitespaces).isEmpty && snippet.author != "佚名" {
                    Text(authorText).font(.system(size: 14, weight: .medium, design: .serif)).foregroundColor(.secondary).fixedSize().offset(x: 20,y: -2)
                }
            }
            Spacer()
        }
        .padding(.bottom, 20)
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
                    Text(snippet.content).font(.system(size: 18, weight: .regular, design: .serif)).lineSpacing(14).foregroundColor(.primary.opacity(0.85)).multilineTextAlignment(.center).frame(maxWidth: .infinity, alignment: .center)
                case .lyric, .prose:
                    Text(indentedContent).font(.system(size: 18, weight: .regular, design: .serif)).lineSpacing(14).foregroundColor(.primary.opacity(0.85)).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                case .quote:
                    Text(snippet.content).font(.system(size: 18, weight: .regular, design: .serif)).lineSpacing(14).foregroundColor(.primary.opacity(0.85)).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 24)
                    HStack { Spacer(); Text("—— \(snippet.author)").font(.system(size: 14, weight: .medium, design: .serif)).foregroundColor(.secondary) }
                case .movie:
                    Text(snippet.content).font(.system(size: 18, weight: .regular, design: .serif)).lineSpacing(14).foregroundColor(.primary.opacity(0.85)).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 24)
                    HStack { Spacer(); Text("—— \(snippet.author)（\(snippet.title)）").font(.system(size: 14, weight: .medium, design: .serif)).foregroundColor(.secondary) }
                case .web:
                    Text(snippet.content).font(.system(size: 18, weight: .regular, design: .serif)).lineSpacing(14).foregroundColor(.primary.opacity(0.85)).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
            
            // ✨ 探测魔法：强制 SwiftUI 计算出文本完整的理想高度
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: SnippetHeightPreferenceKey.self, value: geo.size.height)
                }
            )
            
            // 🔒 智能拦截：控制最大高度
            .frame(height: isTruncated ? maxHeight : nil, alignment: .top)
            
            // 使用纯正的 Alpha 遮罩，让文字自然羽化消失
            .mask {
                if isTruncated {
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0.0),
                            .init(color: .black, location: 0.75), // 顶部 75% 保持完全不透明
                            .init(color: .clear, location: 1.0)   // 底部 25% 逐渐羽化为完全透明
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    Color.black
                }
            }
            .clipped()
            
            // ================= 🌟 展开按钮 =================
            if isTruncated {
                Button(action: onExpand) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.backward.and.arrow.down.forward")
                        Text("全屏沉浸阅读")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(snippet.category.themeColor.opacity(0.9))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 24)
            }
        }
        .overlay(alignment: .topTrailing) {
            Text(snippet.category.displayName).font(.system(size: 11, weight: .bold)).foregroundColor(snippet.category.themeColor).padding(.horizontal, 10).padding(.vertical, 4).background(snippet.category.themeColor.opacity(0.15)).clipShape(Capsule()).padding([.top, .trailing], 16)
        }
        .onPreferenceChange(SnippetHeightPreferenceKey.self) { h in
            if abs(naturalHeight - h) > 1 { naturalHeight = h }
        }
        // ✨✨✨ 核心修复 2：抛弃了极其耗能且容易闪黑的 .ultraThinMaterial 毛玻璃
        // 采用 macOS 原生的卡片基础色 (controlBackgroundColor)，既完美兼容明/暗色模式，又绝对不会在切换时闪黑！
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
        )
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(isHovered ? 0.15 : 0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.06), radius: isHovered ? 16 : 8, y: isHovered ? 8 : 4)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.appSnappy, value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2, perform: onEdit)
    }
}

// MARK: - 📖 4. 极致沉浸：全屏阅读视图 (自适应全宽版)
struct SnippetFullscreenReadingView: View {
    let snippet: Snippet
    var onClose: () -> Void
    
    private var indentedContent: String {
        snippet.content.components(separatedBy: .newlines).map { "\u{3000}\u{3000}" + $0 }.joined(separator: "\n")
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 背景深度模糊遮罩，阻断后方视线
            Color.black.opacity(0.4).ignoresSafeArea()
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            
            // 核心阅读流
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 40) {
                    
                    // 头部信息
                    if [.poetry, .lyric, .prose].contains(snippet.category) {
                        VStack(spacing: 16) {
                            Text(snippet.title)
                                .font(.system(size: 36, weight: .heavy, design: .serif))
                                .foregroundColor(.primary)
                            
                            let authorText = "\(snippet.author)\(snippet.dynasty.isEmpty ? "" : " (\(snippet.dynasty))")"
                            if !authorText.trimmingCharacters(in: .whitespaces).isEmpty && snippet.author != "佚名" {
                                Text(authorText)
                                    .font(.system(size: 16, weight: .medium, design: .serif))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 100)
                    } else {
                        Spacer().frame(height: 80)
                    }
                    
                    // 巨型正文排版
                    switch snippet.category {
                    case .poetry:
                        Text(snippet.content).font(.system(size: 20, weight: .regular, design: .serif)).lineSpacing(18).foregroundColor(.primary.opacity(0.9)).multilineTextAlignment(.center).frame(maxWidth: .infinity, alignment: .center)
                    case .lyric, .prose:
                        Text(indentedContent).font(.system(size: 20, weight: .regular, design: .serif)).lineSpacing(18).foregroundColor(.primary.opacity(0.9)).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                    case .quote, .movie, .web:
                        Text(snippet.content).font(.system(size: 20, weight: .regular, design: .serif)).lineSpacing(18).foregroundColor(.primary.opacity(0.9)).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // 尾部落款
                    if snippet.category == .quote {
                        HStack { Spacer(); Text("—— \(snippet.author)").font(.system(size: 16, weight: .medium, design: .serif)).foregroundColor(.secondary) }.padding(.top, 24)
                    } else if snippet.category == .movie {
                        HStack { Spacer(); Text("—— \(snippet.author)（\(snippet.title)）").font(.system(size: 16, weight: .medium, design: .serif)).foregroundColor(.secondary) }.padding(.top, 24)
                    }
                    
                    // 尾部排版与注释
                    if !snippet.annotation.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Divider()
                            Text("注解 / 释义").font(.system(size: 14, weight: .bold)).foregroundColor(.secondary)
                            Text(snippet.annotation)
                                .font(.system(size: 15, design: .serif))
                                .lineSpacing(10)
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 60)
                    }
                }
                .padding(.horizontal, 120)
                .padding(.bottom, 150)
                .frame(maxWidth: .infinity)
            }
            
            // 退出按钮
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(32)
        }
        // 绑定全局 ESC 键直接退出
        .background(
            Button("") { onClose() }.keyboardShortcut(.cancelAction).opacity(0)
        )
    }
}

#Preview("日常摘录画廊") {
    let schema = Schema([Snippet.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    InkGalleryView(
        activeCategory: .constant(.all),
        searchText: .constant(""),
        sortType: .constant(.newest),
        isCarouselMode: .constant(true), // 预览横向模式
        isBatchEditMode: .constant(false),
        selectedSnippetsForBatch: .constant([])
    )
    .frame(width: 1200, height: 800)
    .modelContainer(container)
}
#endif
