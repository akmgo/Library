#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

// MARK: - 🎛️ 离散式网格缩放引擎

enum GalleryGridScale: Double, CaseIterable {
    case small = 0.0; case medium = 1.0; case large = 2.0; case extraLarge = 3.0
    var width: CGFloat {
        switch self { case .small: 118; case .medium: 152; case .large: 188; case .extraLarge: 238 }
    }

    var hSpacing: CGFloat {
        switch self { case .small: 18; case .medium: 22; case .large: 28; case .extraLarge: 34 }
    }

    var vSpacing: CGFloat {
        switch self { case .small: 22; case .medium: 28; case .large: 34; case .extraLarge: 42 }
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
    var id: String { rawValue }
    var description: String { rawValue }
}

enum GalleryFilterTab: String, CaseIterable, CustomStringConvertible {
    case all = "全部书籍"; case planned = "想读书籍"; case unread = "待读书籍"
    case reading = "在读书籍"; case finished = "已读书籍"; case abandoned = "弃读书籍"
    var description: String { rawValue }

    var status: BookStatus? {
        switch self {
        case .all: return nil
        case .planned: return .planned
        case .unread: return .unread
        case .reading: return .reading
        case .finished: return .finished
        case .abandoned: return .abandoned
        }
    }
}

// MARK: - 🌟 核心全景画廊视图

struct GalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedBook: Book?
    @Query private var allBooks: [Book]
    
    @Binding var activeTab: GalleryFilterTab
    @Binding var searchText: String
    @Binding var sortType: GallerySortType
    @Binding var scaleIndex: Double
    @Binding var isBatchEditMode: Bool
    @Binding var selectedBooksForBatch: Set<String>
    
    @State private var isEntranceAnimated: Bool = false

    private var gallerySnapshot: ReadingStatsCalculator.BookGallerySnapshot {
        ReadingStatsCalculator.bookGallerySnapshot(
            books: allBooks,
            filterStatus: activeTab.status,
            searchText: searchText,
            sortKey: sortType.gallerySortKey
        )
    }
    
    private var currentScale: GalleryGridScale {
        GalleryGridScale(rawValue: scaleIndex) ?? .large
    }
    
    var body: some View {
        GeometryReader { geo in
            // 1. 主体滚动区
            ScrollView {
                gridView(containerWidth: geo.size.width)
                    .padding(.horizontal, horizontalPadding(for: geo.size.width))
                    .padding(.top, 140)
                    .padding(.bottom, isBatchEditMode ? 120 : 60)
                    .opacity(isEntranceAnimated ? 1.0 : 0.0)
                    .offset(y: isEntranceAnimated ? 0 : 150)
                    .scaleEffect(isEntranceAnimated ? 1.0 : 0.99, anchor: .center)
                    .animation(.appFluidSpring, value: isEntranceAnimated)
            }
            // 2. 顶部 Header (overlay 挂载)
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        // 左侧文字区
                        VStack(alignment: .leading, spacing: 8) {
                            Text("全景画廊")
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)
                            Text("共收录 \(gallerySnapshot.books.count) 本图书")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .opacity(isEntranceAnimated ? 1.0 : 0.0)
                        .offset(x: isEntranceAnimated ? 0 : -200)
                        
                        Spacer()
                        
                        // 右侧数据区
                        MiniInventoryBar(totalCount: gallerySnapshot.totalInventoryCount, dataPoints: gallerySnapshot.inventoryPoints)
                            .frame(width: 320)
                            .opacity(isEntranceAnimated ? 1.0 : 0.0)
                            .offset(x: isEntranceAnimated ? 0 : 200)
                    }
                    .padding(.horizontal, horizontalPadding(for: geo.size.width)).padding(.top, 45).padding(.bottom, 20)
                    .animation(.appFluidSpring, value: isEntranceAnimated)
                    
                    Divider().background(Color.primary.opacity(0.05))
                }
                .background(Color.clear.background(.ultraThinMaterial).opacity(0.85))
                .ignoresSafeArea(edges: .top)
            }
            // 3. 底部批处理控制栏
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
            if !isEntranceAnimated {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.appFluidSpring) { isEntranceAnimated = true }
                }
            }
        }
    }
    
    @ViewBuilder
    private func gridView(containerWidth: CGFloat) -> some View {
        if gallerySnapshot.books.isEmpty {
            EmptyStateView(
                systemImage: "books.vertical.fill",
                title: "没有找到相关书籍",
                message: searchText.isEmpty ? "试试切换分类或点击添加书籍" : "尝试更换搜索关键词",
                minHeight: 400
            )
        } else {
            let columns = [GridItem(.adaptive(minimum: currentScale.width, maximum: currentScale.width), spacing: currentScale.hSpacing)]
            LazyVGrid(columns: columns, spacing: currentScale.vSpacing) {
                ForEach(gallerySnapshot.books) { book in
                    AnimatedCardGlide(
                        book: book, activeTab: activeTab.rawValue,
                        isBatchEditMode: isBatchEditMode, gridScale: currentScale,
                        selectedBooksForBatch: $selectedBooksForBatch, selectedBook: $selectedBook
                    )
                    .transition(.appCardGlide)
                }
            }
            .animation(.appFluidSpring, value: scaleIndex)
        }
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        min(max(width * 0.045, 28), 56)
    }
    
    private func deleteSelectedBooks() {
        let booksToDelete = gallerySnapshot.books.filter { selectedBooksForBatch.contains($0.id) }
        try? ReadingDataService.shared.deleteBooks(booksToDelete, context: modelContext)
        withAnimation(.appSnappy) {
            isBatchEditMode = false
            selectedBooksForBatch.removeAll()
        }
    }
}

extension GallerySortType {
    var gallerySortKey: BookGallerySortKey {
        switch self {
        case .newest:
            return .newest
        case .oldest:
            return .oldest
        case .titleAsc:
            return .titleAscending
        }
    }
}
#endif
