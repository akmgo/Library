#if os(macOS)
import SwiftData
import SwiftUI
import AppKit

// MARK: - ✨ Apple Studio 级全息 Cover Flow (扑克牌叠放特效版)

/// macOS 专属的 3D 全息漫游画廊视图。
///
/// **视觉交互设计：**
/// 彻底复刻经典的 Apple Cover Flow 体验，并加入了现代化的玻璃质感与环境光：
/// - 底层应用了动态的 `AmbientGlowBackground`，随 C 位书籍提取色彩模糊映射。
/// - 支持触控板或鼠标横向滚动、以及按钮点击的弹性阻尼切换。
/// - 支持 C 位悬停及点击触发 Spotlight（聚光灯）放大特效。
///
/// - 注意: 为了防止滚动事件（`NSEvent`）与原生 ScrollView 冲突，内部通过底层的本地事件监视器拦截滚动增量。
struct CarouselWidget: View {
    @Query var books: [Book]
    
    let namespace: Namespace.ID
    @Binding var selectedBook: Book?
    @Binding var activeCoverID: String
    
    /// 当前所选的书籍分类标签 (如 "ALL", "WANT" 等)
    @State private var activeTab: String = "ALL"
    /// 根据标签过滤排序后，用于 3D 渲染的书单阵列
    @State private var displayBooks: [Book] = []
    
    /// 3D 轮播图当前停留在屏幕绝对 C 位的书籍索引
    @State private var currentIndex: Int = 0
    /// 防止触控板滚动过快导致轮播抽搐的安全防抖锁
    @State private var isScrolling = false
    /// 鼠标是否正悬停在 C 位卡片感应区上
    @State private var isHoveringCenter = false
    /// 本地鼠标/触控板滚动事件监听器钩子
    @State private var scrollEventMonitor: Any?
    
    /// C 位焦点高亮开关，开启时 C 位卡片会弹起并放大，两侧卡片会避让沉降
    @State private var isSpotlighted: Bool = false
    
    // 排版锚点常量
    let centerOffset: CGFloat = 160
    let sideSpacing: CGFloat = 40
    let cardWidth: CGFloat = 300
    
    /// 安全提取当前的 C 位书籍，用于反向驱动底层的全息环境光变色。
    var currentCenterBook: Book? {
        guard displayBooks.indices.contains(currentIndex) else { return nil }
        return displayBooks[currentIndex]
    }
    
    var body: some View {
        Group {
            if displayBooks.isEmpty {
                ContentUnavailableView {
                    Label(emptyStateTitle, systemImage: "cube.transparent.fill")
                } description: {
                    Text(emptyStateDescription)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            } else {
                GeometryReader { geo in
                    ZStack(alignment: .top) {
                        // 1. 替换原生背景，使用跨平台环境光
                        AmbientGlowBackground(book: currentCenterBook)
                        
                        // 2. 3D 画廊主体
                        VStack(spacing: 0) {
                            Spacer().frame(height: 250)
                            mainCoverFlowGallery(viewWidth: geo.size.width)
                            Spacer()
                        }
                        
                        // 3. 玻璃 Header
                        VStack(spacing: 0) {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("全息漫游")
                                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                                        .foregroundColor(.primary)
                                    Text("沉浸式 3D 空间陈列")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                
                                if !displayBooks.isEmpty {
                                    HStack(spacing: 20) {
                                        Text(displayBooks[currentIndex].title ?? "未知书籍")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                            .frame(maxWidth: 240, alignment: .trailing)
                                            .animation(.easeInOut(duration: 0.3), value: currentIndex)
                                        
                                        Rectangle().fill(Color.primary.opacity(0.1)).frame(width: 1, height: 20)
                                        
                                        HStack(spacing: 8) {
                                            CarouselControlButton(icon: "chevron.left") { moveIndex(delta: -1) }
                                            CarouselControlButton(icon: "chevron.right") { moveIndex(delta: 1) }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 40)
                            .padding(.top, 45)
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
                    .ignoresSafeArea(edges: .top)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker(selection: $activeTab, label: EmptyView()) {
                        Text("全部书籍").tag("ALL")
                        Text("想读书籍").tag("WANT")
                        Text("待读书籍").tag("UNREAD")
                        Text("已读书籍").tag("FINISHED")
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } label: {
                    Image(systemName: activeTab == "ALL" ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                        .foregroundColor(activeTab == "ALL" ? .primary : .accentColor)
                }
                .menuIndicator(.hidden)
                .help("分类筛选")
            }
        }
        .onAppear {
            updateDisplayBooks(animate: false)
            // 劫持本地横向滚动事件，用于驱动 3D 轮播切换
            scrollEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                if isHoveringCenter { if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) { handleScroll(event: event); return nil } }
                return event
            }
        }
        .onChange(of: books) { _, _ in updateDisplayBooks(animate: true) }
        .onChange(of: activeTab) { _, _ in updateDisplayBooks(animate: true) }
        .onDisappear {
            if let monitor = scrollEventMonitor { NSEvent.removeMonitor(monitor) }
            if isHoveringCenter { NSCursor.pop() }
        }
    }
    
    private var emptyStateTitle: String { "书境空空如也" }
    private var emptyStateDescription: String { "去主页录入您的第一本书，开启 3D 空间漫游吧。" }
    
    // MARK: - 内部排版引擎
    
    /// 根据当前屏幕的物理宽度，动态计算需要渲染的卡片索引窗口。
    ///
    /// 这是一个关键的性能优化：避免将数百本书同时压入 ZStack，而是通过数学推导，
    /// 仅提取屏幕可见范围及其左右缓冲区内的 `dynamicSideCount` 本书进行几何构建。
    ///
    /// - Parameter containerWidth: 当前渲染容器的物理宽度。
    /// - Returns: 包含安全索引以及它与当前 C 位距离差距（diff）的元组数组。
    private func calculateVisibleWindow(containerWidth: CGFloat) -> [(book: Book, diff: Int)] {
        guard !displayBooks.isEmpty else { return [] }
        let total = displayBooks.count
        
        let singleSideUsableWidth = (containerWidth / 2.0) - (centerOffset + cardWidth / 2.0)
        let baseSideCount = max(2, Int(singleSideUsableWidth / sideSpacing))
        let offScreenBuffer = 4
        let dynamicSideCount = baseSideCount + offScreenBuffer
        let range = min(dynamicSideCount, (total - 1) / 2)
        
        var window: [(book: Book, diff: Int)] = []
        for diff in -range ... range {
            var actualIndex = (currentIndex + diff) % total
            if actualIndex < 0 { actualIndex += total }
            window.append((book: displayBooks[actualIndex], diff: diff))
        }
        return window
    }
    
    @ViewBuilder
    private func mainCoverFlowGallery(viewWidth: CGFloat) -> some View {
        ZStack {
            ForEach(calculateVisibleWindow(containerWidth: viewWidth), id: \.book.id) { item in
                CoverFlowCardItem(
                    book: item.book,
                    diff: item.diff,
                    centerOffset: centerOffset,
                    sideSpacing: sideSpacing,
                    isSpotlighted: isSpotlighted
                )
                .onTapGesture { if item.diff != 0 { moveIndex(delta: item.diff) } }
                .zIndex(Double(100 - abs(item.diff)))
            }
            
            // 隐形的 C 位热区捕捉器
            if !displayBooks.isEmpty {
                Rectangle()
                    .fill(Color.white.opacity(0.001))
                    .contentShape(Rectangle())
                    .frame(width: 300, height: 450)
                    .offset(y: 10)
                    .zIndex(1000)
                    .onHover { isHovered in
                        isHoveringCenter = isHovered
                        DispatchQueue.main.async {
                            if isHovered { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                            isSpotlighted.toggle()
                        }
                    }
                    .gesture(DragGesture().onEnded { value in
                        let threshold: CGFloat = 30
                        if value.translation.width < -threshold { moveIndex(delta: -1) }
                        else if value.translation.width > threshold { moveIndex(delta: 1) }
                    })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 600)
        .zIndex(1)
    }
    
    // MARK: - 逻辑与交互事件处理
    
    /// 更新画廊的展示数组，处理分类切换的逻辑。
    private func updateDisplayBooks(animate: Bool = false) {
        let updateAction = {
            switch activeTab {
            case "WANT": displayBooks = books.filter { $0.isWantToRead }.sorted { ($0.title ?? "") < ($1.title ?? "") }
            case "UNREAD": displayBooks = books.filter { $0.status == .unread || $0.status == .reading }.sorted { ($0.startTime ?? Date.distantPast) > ($1.startTime ?? Date.distantPast) }
            case "FINISHED": displayBooks = books.filter { $0.status == .finished }.sorted { ($0.endTime ?? Date.distantPast) > ($1.endTime ?? Date.distantPast) }
            default: displayBooks = books.sorted { ($0.title ?? "") < ($1.title ?? "") }
            }
            if currentIndex >= displayBooks.count { currentIndex = max(0, displayBooks.count - 1) }
        }
        if animate { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { updateAction() } }
        else { updateAction() }
    }

    /// 分析并消化底层的 `NSEvent` 滚动意图。
    /// 内置防抖锁，保证动画执行期间不会被大量连续的滚轮事件打乱阵脚。
    private func handleScroll(event: NSEvent) {
        if event.momentumPhase.contains(.began) || event.momentumPhase.contains(.changed) { return }
        guard !isScrolling else { return }
        
        let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 25.0 : 2.0
        let deltaX = event.scrollingDeltaX
        
        if deltaX < -threshold {
            isScrolling = true; moveIndex(delta: 1)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { isScrolling = false }
        } else if deltaX > threshold {
            isScrolling = true; moveIndex(delta: -1)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { isScrolling = false }
        }
    }

    /// 根据步长驱动底层索引，触发整个视图环的弹性位移重算。
    private func moveIndex(delta: Int) {
        guard !displayBooks.isEmpty else { return }
        
        if isSpotlighted {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { isSpotlighted = false }
        }
        
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            let nextIndex = currentIndex + delta
            if nextIndex >= displayBooks.count { currentIndex = nextIndex % displayBooks.count }
            else if nextIndex < 0 { currentIndex = (nextIndex % displayBooks.count) + displayBooks.count }
            else { currentIndex = nextIndex }
        }
    }
}

/// 辅助组件：右上角极简左右控制箭头
private struct CarouselControlButton: View {
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
                .frame(width: 32, height: 32)
                .background(Color.primary.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
#endif
