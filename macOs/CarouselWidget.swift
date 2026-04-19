import SwiftData
import SwiftUI

#if os(macOS)
import AppKit

// MARK: - ✨ Apple Studio 级全息 Cover Flow (扑克牌叠放特效版)

struct CarouselWidget: View {
    @Query var books: [Book]
    
    let namespace: Namespace.ID
    @Binding var selectedBook: Book?
    @Binding var activeCoverID: String
    @State private var activeTab: String = "ALL"
    @State private var displayBooks: [Book] = []
    
    @State private var currentIndex: Int = 0
    @State private var isScrolling = false
    @State private var isHoveringCenter = false
    @State private var scrollEventMonitor: Any?
    
    @State private var isSpotlighted: Bool = false
    
    let centerOffset: CGFloat = 160
    let sideSpacing: CGFloat = 40
    let cardWidth: CGFloat = 300
    
    // ✨ 安全获取当前 C 位书籍，用于环境光
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
                        // ✨ 1. 替换原生背景，使用跨平台环境光
                        AmbientGlowBackground(book: currentCenterBook)
                        
                        // ================= 2. 3D 画廊主体 =================
                        VStack(spacing: 0) {
                            Spacer().frame(height: 250)
                            mainCoverFlowGallery(viewWidth: geo.size.width)
                            Spacer()
                        }
                        
                        // ================= 3. 玻璃 Header =================
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
    
    private var emptyStateTitle: String { "书境空空如也" }
    private var emptyStateDescription: String { "去主页录入您的第一本书，开启 3D 空间漫游吧。" }
    
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

// MARK: - ✨ 3D 单个卡片组件 (macOS 专属)
private struct CoverFlowCardItem: View {
    let book: Book
    let diff: Int
    
    let centerOffset: CGFloat
    let sideSpacing: CGFloat
    let isSpotlighted: Bool
    
    let cardWidth: CGFloat = 300
    let cardHeight: CGFloat = 450
    
    var body: some View {
        let isCenter = diff == 0
        let rawAbsDiff = abs(CGFloat(diff))
        
        func linearMapPercent(startVal: CGFloat, endVal: CGFloat) -> CGFloat {
            if isCenter { return 1.0 }
            let normalizeFactor = max(0.0, 1.0 - rawAbsDiff / 12.0)
            return endVal + (startVal - endVal) * normalizeFactor
        }
        
        let rotateY: Double = isCenter ? 0 : (isSpotlighted ? 0 : (diff < 0 ? 60 : -60))
        let scale: CGFloat = isCenter ? (isSpotlighted ? 1.15 : 1.0) : (isSpotlighted ? 0.82 : max(0.55, 1.0 - rawAbsDiff * 0.05))
        let alignYOffset: CGFloat = cardHeight * (1.0 - scale) / 2.0
        let spotlightJump: CGFloat = 40
        let activeCenterOffset = isSpotlighted ? centerOffset * 1.5 : centerOffset
        let activeSideSpacing = isSpotlighted ? 45.0 : sideSpacing
        
        let translateX: CGFloat = isCenter ? 0 : (diff < 0 ? -activeCenterOffset - (rawAbsDiff - 1) * activeSideSpacing : activeCenterOffset + (rawAbsDiff - 1) * activeSideSpacing)
                
        let darknessOpacity: Double = isCenter ? 0.0 : (isSpotlighted ? 0.15 : min(0.4, Double(rawAbsDiff) * 0.1))
        let reflectionLocation = linearMapPercent(startVal: 0.8, endVal: 0.5)

        let safeTitle = book.title ?? "未知书名"
        let safeAuthor = (book.author ?? "未知作者").uppercased()
        
        return ZStack(alignment: .top) {
            // 顶部悬浮的标题与作者
            VStack(spacing: 8) {
                Text(safeTitle)
                    .font(.system(size: isSpotlighted ? 40 : 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
                
                Text(safeAuthor)
                    .font(.system(size: isSpotlighted ? 16 : 13, weight: .bold, design: .rounded))
                    .tracking(4)
                    .foregroundColor(.secondary)
            }
            .frame(width: cardWidth + 300)
            .opacity(isCenter ? 1 : 0)
            .offset(y: isCenter ? (isSpotlighted ? -120 : -90) : -70)
            .zIndex(3)
            
            // 封面与倒影主体
            ZStack {
                // 底层接触阴影
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(isCenter ? 0.25 : 0.05))
                    .blur(radius: isCenter ? (isSpotlighted ? 25 : 12) : 4)
                    .offset(y: isCenter ? (isSpotlighted ? 30 : 20) : 6)
                    .scaleEffect(0.95)
                    .zIndex(0)

                // 倒影
                LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                    .frame(width: cardWidth, height: cardHeight).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .rotation3DEffect(.degrees(180), axis: (x: 1, y: 0, z: 0))
                    .mask(
                        LinearGradient(stops: [
                            .init(color: .black.opacity(0.7), location: 0.0),
                            .init(color: .clear, location: Double(reflectionLocation))
                        ], startPoint: .top, endPoint: .bottom)
                    )
                    .offset(y: cardHeight + (isCenter && isSpotlighted ? spotlightJump * 2 + 10 : 2))
                    .opacity(isCenter ? 0.8 : 0.2)
                    .zIndex(1)
                
                // 实体卡片
                ZStack {
                    LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                        .frame(width: cardWidth, height: cardHeight)
                    
                    // ✨ 新增书脊物理高光渐变
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.35), location: 0.0),
                            .init(color: .white.opacity(0.0), location: 0.08)
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                    
                    Color.black.opacity(darknessOpacity)
                    
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(isCenter ? 0.15 : 0.08), lineWidth: 1)
                }
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .zIndex(2)
            }
            .frame(width: cardWidth, height: cardHeight)
            .zIndex(1)
        }
        .frame(width: cardWidth, height: 850)
        .rotation3DEffect(.degrees(rotateY), axis: (x: 0, y: 1, z: 0), perspective: 0.3)
        .scaleEffect(scale)
        .offset(x: translateX, y: alignYOffset)
        .offset(y: isSpotlighted ? (isCenter ? -spotlightJump : 15) : 0)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: diff)
        .animation(.spring(response: 0.55, dampingFraction: 0.75), value: isSpotlighted)
    }
}
#endif
