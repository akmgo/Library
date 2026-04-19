import SwiftData
import SwiftUI

#if os(iOS)
struct MobileCarouselView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Query var books: [Book]
    
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    
    @State private var showDetail: Bool = false
    @State private var selectedBookForDetail: Book? = nil
    
    var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    /// ✨ 安全获取当前 C 位书籍，用于氛围光
    var currentCenterBook: Book? {
        guard !books.isEmpty else { return nil }
        let safeIndex = (currentIndex % books.count + books.count) % books.count
        return books[safeIndex]
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    // ✨ 替换原来的系统底色，引入跨平台环境氛围光
                    AmbientGlowBackground(book: currentCenterBook)
                    
                    if books.isEmpty {
                        emptyState
                    } else {
                        ZStack {
                            ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                                let diff = normalizedDiff(index: index, totalCount: books.count)
                                                            
                                // ✨ 核心修复：大幅增加两侧渲染的卡片数量！
                                // 竖屏一侧展示 8 张，横屏一侧展示 15 张，让扑克牌无缝延伸到屏幕边缘
                                let visibleRange = isLandscape ? 15 : 6
                                                            
                                if abs(diff) <= visibleRange {
                                    carouselCard(book: book, diff: diff, geo: geo)
                                        .zIndex(Double(100 - abs(diff)))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .gesture(
                            DragGesture()
                                .onChanged { value in dragOffset = value.translation.width }
                                .onEnded { value in
                                    let threshold: CGFloat = 30
                                    if value.translation.width < -threshold { moveIndex(1) }
                                    else if value.translation.width > threshold { moveIndex(-1) }
                                    dragOffset = 0
                                }
                        )
                    }
                }
            }
            .navigationTitle("全息书景")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showDetail) {
                if let selected = selectedBookForDetail { MobileBookDetailView(book: selected) }
            }
            .toolbar(isLandscape ? .hidden : .visible, for: .tabBar)
            .toolbar(isLandscape ? .hidden : .visible, for: .navigationBar)
        }
    }
    
    // MARK: - 核心：双模态 Cover Flow 引擎

    private func carouselCard(book: Book, diff: Int, geo: GeometryProxy) -> some View {
        let absDiff = abs(CGFloat(diff)); let isCenter = diff == 0
        
        let cardWidth: CGFloat = isLandscape ? (geo.size.height * 0.6 / 1.5) : (geo.size.width * 0.55)
        let cardHeight: CGFloat = cardWidth * 1.5
        
        let rotateY: Double = isCenter ? 0 : (diff < 0 ? 48 : -48)
        let scale: CGFloat = isCenter ? 1.0 : max(0.55, 1.0 - absDiff * 0.08)
        let alignYOffset: CGFloat = cardHeight * (1.0 - scale) / 2.0
        
        // ✨ 优化：大幅缩小横屏时的卡片间距，制造与竖屏一致的物理叠放（遮挡）纵深感
        let centerOffset: CGFloat = isLandscape ? cardWidth * 0.6 : cardWidth * 0.65
        let sideSpacing: CGFloat = isLandscape ? cardWidth * 0.2 : cardWidth * 0.18
        
        let dragShift = isCenter ? dragOffset : (dragOffset * 0.3)
        let translateX = isCenter ? dragShift : (diff < 0 ? -centerOffset - (absDiff - 1) * sideSpacing + dragShift : centerOffset + (absDiff - 1) * sideSpacing + dragShift)
        
        let darknessOpacity: Double = isCenter ? 0.0 : min(0.6, Double(absDiff) * 0.15)
        let baseShadowOpacity: Double = isCenter ? 0.3 : 0.1
        let reflectionOpacity: Double = isCenter ? 0.8 : max(0.2, 0.6 - Double(absDiff) * 0.1)

        let safeTitle = book.title ?? "未知书名"
        let safeAuthor = (book.author ?? "未知作者").uppercased()
        
        return ZStack(alignment: .top) {
            // 文本标题层
            VStack(spacing: 4) {
                Text(safeTitle).font(.system(size: isLandscape ? 22 : 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary).lineLimit(1)
                    // ✨ 加一层极淡的环境底色阴影，防止被氛围光吞没
                    .shadow(color: Color(uiColor: .systemGroupedBackground).opacity(0.8), radius: 2)
                
                Text(safeAuthor).font(.system(size: isLandscape ? 11 : 13, weight: .medium, design: .rounded)).tracking(3).foregroundColor(.secondary)
            }
            .frame(width: cardWidth + 100).opacity(isCenter ? 1 : 0)
            // ✨ 加入 Y 轴微调，让文字显示时有一点点弹性的呼吸感
            .offset(y: isLandscape ? -60 : (isCenter ? -80 : -65))
            .zIndex(3)
            
            // 实体卡片组
            ZStack {
                // 1. 底面阴影
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(baseShadowOpacity))
                    .blur(radius: 10).offset(y: isCenter ? 15 : 5).zIndex(0)
                
                // 2. 镜面倒影
                LocalCoverView(coverData: book.coverData ?? Data(), fallbackTitle: safeTitle)
                    .frame(width: cardWidth, height: cardHeight).clipShape(RoundedRectangle(cornerRadius: 12))
                    .rotation3DEffect(.degrees(180), axis: (x: 1, y: 0, z: 0))
                    .mask(LinearGradient(stops: [
                        .init(color: .black.opacity(0.5), location: 0.0),
                        .init(color: .clear, location: isLandscape ? 0.8 : 0.5)
                    ], startPoint: .top, endPoint: .bottom))
                    .offset(y: cardHeight + 4).opacity(reflectionOpacity).zIndex(1)
                
                // 3. 封面本体
                ZStack {
                    LocalCoverView(coverData: book.coverData ?? Data(), fallbackTitle: safeTitle).frame(width: cardWidth, height: cardHeight)
                    
                    // ✨ 新增书脊物理高光渐变
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.35), location: 0.0),
                            .init(color: .white.opacity(0.0), location: 0.08)
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                    
                    Color.black.opacity(darknessOpacity)
                    RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(isCenter ? 0.2 : 0.05), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(isCenter ? 0.2 : 0.0), radius: isCenter ? 20 : 0, y: isCenter ? 10 : 0)
                .zIndex(2)
            }
            .frame(width: cardWidth, height: cardHeight).zIndex(1)
            .onTapGesture {
                if isCenter {
                    let impact = UIImpactFeedbackGenerator(style: .medium); impact.impactOccurred()
                    selectedBookForDetail = book; showDetail = true
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { moveIndex(diff) }
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight * 2)
        .rotation3DEffect(.degrees(rotateY), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .scaleEffect(scale)
        .offset(x: translateX, y: alignYOffset + (isLandscape ? -45 : 30))
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: currentIndex)
        .animation(.interactiveSpring, value: dragOffset)
    }
    
    private func normalizedDiff(index: Int, totalCount: Int) -> Int {
        if totalCount == 0 { return 0 }
        var diff = index - currentIndex
        let half = totalCount / 2
        if diff > half { diff -= totalCount } else if diff < -half { diff += totalCount }
        return diff
    }
    
    private func moveIndex(_ delta: Int) {
        if books.isEmpty { return }
        let impact = UIImpactFeedbackGenerator(style: .light); impact.impactOccurred()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            let nextIndex = currentIndex + delta
            if nextIndex >= books.count { currentIndex = nextIndex % books.count }
            else if nextIndex < 0 { currentIndex = (nextIndex % books.count) + books.count }
            else { currentIndex = nextIndex }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "view.3d").font(.system(size: 48)).foregroundColor(Color.gray.opacity(0.5))
            Text("藏书馆空空如也").font(.system(size: 16, weight: .bold)).foregroundColor(.secondary)
        }
    }
}
#endif
