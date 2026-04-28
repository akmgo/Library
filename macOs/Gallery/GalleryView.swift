#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

// MARK: - 🎛️ 离散式网格缩放引擎

enum GalleryGridScale: Double, CaseIterable {
    case small = 0.0; case medium = 1.0; case large = 2.0; case extraLarge = 3.0
    var width: CGFloat {
        switch self { case .small: 120; case .medium: 160; case .large: 200; case .extraLarge: 260 }
    }

    var hSpacing: CGFloat {
        switch self { case .small: 20; case .medium: 24; case .large: 32; case .extraLarge: 40 }
    }

    var vSpacing: CGFloat {
        switch self { case .small: 24; case .medium: 32; case .large: 40; case .extraLarge: 50 }
    }

    var titleFont: CGFloat {
        switch self { case .small: 12; case .medium: 13; case .large: 15; case .extraLarge: 18 }
    }

    var subFont: CGFloat {
        switch self { case .small: 10; case .medium: 11; case .large: 13; case .extraLarge: 15 }
    }

    var uiScale: CGFloat {
        switch self { case .small: 0.75; case .medium: 0.85; case .large: 1.0; case .extraLarge: 1.2 }
    }
}

enum GallerySortType: String, CaseIterable, Identifiable, CustomStringConvertible {
    case newest = "最近添加"; case oldest = "最早添加"; case titleAsc = "书名 (A-Z)"
    var id: String {
        rawValue
    }

    var description: String {
        rawValue
    }
}

enum ArchiveFilterTab: String, CaseIterable, CustomStringConvertible {
    case all = "全部书籍"; case wantToRead = "想读书籍"; case unread = "待读书籍"
    case reading = "在读书籍"; case finished = "已读书籍"; case abandoned = "弃读书籍"
    var description: String {
        rawValue
    }

    var status: BookStatus? {
        switch self {
        case .all: return nil
        case .wantToRead: return .wantToRead
        case .unread: return .unread
        case .reading: return .reading
        case .finished: return .finished
        case .abandoned: return .abandoned
        }
    }
}

// MARK: - 🌟 核心全景画廊视图

struct ArchiveGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedBook: Book?
    
    // ✨ 状态上提
    @Binding var activeTab: ArchiveFilterTab
    @Binding var searchText: String
    @Binding var sortType: GallerySortType
    @Binding var scaleIndex: Double
    @Binding var isBatchEditMode: Bool
    @Binding var selectedBooksForBatch: Set<String>
    
    @State private var displayBooks: [Book] = []
    @State private var inventoryData: (total: Int, points: [InventoryDataPoint]) = (0, [])
    
    /// ✨ 终极修复：强制状态驱动首屏动画锁
    @State private var isEntranceAnimated: Bool = false
    
    private var currentScale: GalleryGridScale {
        GalleryGridScale(rawValue: scaleIndex) ?? .large
    }
    
    var body: some View {
        GeometryReader { geo in
            // 1. 主体滚动区 (彻底移除外层 ZStack)
            ScrollView {
                gridView(containerWidth: geo.size.width)
                    .padding(.horizontal, 40)
                    .padding(.top, 140)
                    .padding(.bottom, isBatchEditMode ? 120 : 60)
                    // ✨ 视觉极限强化：统一底部的垂直电梯升空
                    .opacity(isEntranceAnimated ? 1.0 : 0.0)
                    .offset(y: isEntranceAnimated ? 0 : 150)
                    .scaleEffect(isEntranceAnimated ? 1.0 : 0.99, anchor: .center)
                    .animation(.appFluidSpring, value: isEntranceAnimated)
            }
            // 2. ✨ 顶部 Header (转化为 overlay，解除 ZStack 层级负担)
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        // 👈 左侧文字区：戏剧性向右滑入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("全景画廊")
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)
                            Text("共收录 \(displayBooks.count) 本图书")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .opacity(isEntranceAnimated ? 1.0 : 0.0)
                        .offset(x: isEntranceAnimated ? 0 : -200)
                        
                        Spacer()
                        
                        // 👉 右侧数据区：戏剧性向左滑入
                        MiniInventoryBar(totalCount: inventoryData.total, dataPoints: inventoryData.points)
                            .frame(width: 320)
                            .opacity(isEntranceAnimated ? 1.0 : 0.0)
                            .offset(x: isEntranceAnimated ? 0 : 200)
                    }
                    .padding(.horizontal, 40).padding(.top, 45).padding(.bottom, 20)
                    // ✨ 统一使用流体弹簧控制内部元素的横向归位
                    .animation(.appFluidSpring, value: isEntranceAnimated)
                    
                    Divider().background(Color.primary.opacity(0.05))
                }
                .background(Color.clear.background(.ultraThinMaterial).opacity(0.85))
                .ignoresSafeArea(edges: .top)
            }
            // 3. ✨ 底部批处理控制栏 (同样转化为 overlay)
            .overlay(alignment: .bottom) {
                if isBatchEditMode {
                    VStack {
                        Spacer()
                        HStack {
                            Text("已选择 \(selectedBooksForBatch.count) 本书")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                            Button("取消") {
                                withAnimation(.appSnappy) { isBatchEditMode = false; selectedBooksForBatch.removeAll() }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            
                            Button(action: deleteSelectedBooks) {
                                Text("删除选中项")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(selectedBooksForBatch.isEmpty ? Color.gray : Color.red)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedBooksForBatch.isEmpty)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(width: 400)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                        .padding(.bottom, 30)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity).animation(.appSnappy))
                }
            }
        }
        .onAppear {
            // 强制先重刷数据，确保如果是从详情页删完回来的，这里能拿到最新结果
            refreshGalleryData(animate: false)
            
            // 这里的 isEntranceAnimated 逻辑可以保留
            if !isEntranceAnimated {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.appFluidSpring) {
                        isEntranceAnimated = true
                    }
                }
            }
        }
        .onChange(of: activeTab) { _, _ in refreshGalleryData(animate: true) }
        .onChange(of: searchText) { _, _ in refreshGalleryData(animate: true) }
        .onChange(of: sortType) { _, _ in refreshGalleryData(animate: true) }
        // 2. 确保 onReceive 逻辑能够穿透缓存
        .onReceive(NotificationCenter.default.publisher(for: .libraryDidUpdate)) { _ in
            print("📡 画廊接收到更新通知，开始重刷数据...")
            refreshGalleryData(animate: true)
        }
    }
    
    @ViewBuilder
    private func gridView(containerWidth: CGFloat) -> some View {
        if displayBooks.isEmpty {
            ContentUnavailableView { Label("没有找到相关书籍", systemImage: "books.vertical.fill") } description: { Text(searchText.isEmpty ? "试试切换分类或点击添加书籍" : "尝试更换搜索关键词") }
                .frame(maxWidth: .infinity, minHeight: 400)
        } else {
            let columns = [GridItem(.adaptive(minimum: currentScale.width, maximum: currentScale.width), spacing: currentScale.hSpacing)]
            LazyVGrid(columns: columns, spacing: currentScale.vSpacing) {
                ForEach(displayBooks) { book in
                    AnimatedCard_Glide(
                        book: book, activeTab: activeTab.rawValue,
                        isBatchEditMode: isBatchEditMode, gridScale: currentScale,
                        selectedBooksForBatch: $selectedBooksForBatch, selectedBook: $selectedBook
                    )
                    // ✨ 保留 transition，用于分类切换时单张卡片的动态入场
                    .transition(.appCardGlide)
                }
            }
            // 过滤、排序时的洗牌动画
            .animation(.appFluidSpring, value: displayBooks)
            .animation(.appFluidSpring, value: scaleIndex)
        }
    }
    
    private func deleteSelectedBooks() {
        for book in displayBooks where selectedBooksForBatch.contains(book.id) {
            modelContext.delete(book)
        }
        try? modelContext.save()
        withAnimation(.appSnappy) { isBatchEditMode = false; selectedBooksForBatch.removeAll() }
        refreshGalleryData(animate: true)
        // ✨ 这里使用了全局强类型通知
        NotificationCenter.default.post(name: .libraryDidUpdate, object: nil)
    }
}

extension ArchiveGalleryView {
    private func refreshGalleryData(animate: Bool) {
        Task { @MainActor in
            let newStats = fetchInventoryStats()
            let newBooks = fetchDisplayBooks()
            
            // 数据赋值逻辑
            if animate && self.isEntranceAnimated {
                // 如果已经完成首屏渲染，说明是在做过滤操作，使用流体动画更新数据
                withAnimation(.appFluidSpring) {
                    self.inventoryData = newStats
                    self.displayBooks = newBooks
                }
            } else {
                // 首屏渲染，无动画秒塞数据
                self.inventoryData = newStats
                self.displayBooks = newBooks
            }
            
            // ✨ 终极时序：延长等待确保底层数据被完全排版后，再拉开帷幕，消除任何可能存在的残影！
            if !self.isEntranceAnimated {
                try? await Task.sleep(nanoseconds: 60_000_000)
                withAnimation(.appFluidSpring) {
                    self.isEntranceAnimated = true
                }
            }
        }
    }
    
    @MainActor
    private func fetchInventoryStats() -> (total: Int, points: [InventoryDataPoint]) {
        let desc = FetchDescriptor<Book>(); let allBooks = (try? modelContext.fetch(desc)) ?? []
        var finished = 0, reading = 0, want = 0, unread = 0, abandoned = 0
        for b in allBooks {
            switch b.status { case .finished: finished+=1; case .reading: reading+=1; case .wantToRead: want+=1; case .unread: unread+=1; case .abandoned: abandoned+=1 }
        }
        let totalCount = finished + reading + want + unread + abandoned
        guard totalCount > 0 else { return (0, []) }
        let rawStats: [(label: String, count: Int, color: Color)] = [("已读", finished, .indigo), ("在读", reading, .blue), ("未读", unread, .gray), ("想读", want, .orange), ("弃读", abandoned, .red)]
        return (totalCount, rawStats.filter { $0.count > 0 }.map { stat in InventoryDataPoint(label: stat.label, count: stat.count, color: stat.color, percentage: Double(stat.count) / Double(totalCount)) })
    }
    
    @MainActor
    private func fetchDisplayBooks() -> [Book] {
        let desc = FetchDescriptor<Book>(); var allBooks = (try? modelContext.fetch(desc)) ?? []
        if let targetStatus = activeTab.status { allBooks = allBooks.filter { $0.status == targetStatus } }
        
        if !searchText.isEmpty {
            let lower = searchText.lowercased()
            allBooks = allBooks.filter { $0.title.lowercased().contains(lower) || $0.author.lowercased().contains(lower) || $0.tags.contains { $0.lowercased().contains(lower) } }
        }
        
        switch sortType { case .newest: allBooks.sort(by: { $0.createdAt > $1.createdAt }); case .oldest: allBooks.sort(by: { $0.createdAt < $1.createdAt }); case .titleAsc: allBooks.sort(by: { $0.title < $1.title }) }
        return allBooks
    }
}

#Preview("全景画廊 (完整视图)") {
    struct GalleryPreviewWrapper: View {
        @State private var selectedBook: Book? = nil
        @State private var activeTab: ArchiveFilterTab = .all
        @State private var searchText: String = ""
        @State private var sortType: GallerySortType = .newest
        @State private var scaleIndex: Double = 2.0
        @State private var isBatchEditMode: Bool = false
        @State private var selectedBooksForBatch: Set<String> = []

        var body: some View {
            ArchiveGalleryView(
                selectedBook: $selectedBook,
                activeTab: $activeTab,
                searchText: $searchText,
                sortType: $sortType,
                scaleIndex: $scaleIndex,
                isBatchEditMode: $isBatchEditMode,
                selectedBooksForBatch: $selectedBooksForBatch
            )
            .frame(width: 1000, height: 750)
        }
    }
    return GalleryPreviewWrapper().modelContainer(PreviewData.shared)
}
#endif
