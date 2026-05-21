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

// MARK: - 🌟 核心全景画廊视图

struct GalleryView: View {
    @Binding var selectedBook: Book?
    @Query private var allBooks: [Book]
    
    private var gallerySnapshot: ReadingStatsCalculator.BookGallerySnapshot {
        ReadingStatsCalculator.bookGallerySnapshot(
            books: allBooks,
            filterStatus: nil,
            searchText: "",
            sortKey: .newest
        )
    }
    
    private var currentScale: GalleryGridScale {
        .large
    }
    
    var body: some View {
        GeometryReader { geo in
            // 1. 主体滚动区
            ScrollView {
                gridView(containerWidth: geo.size.width)
                    .padding(.horizontal, horizontalPadding(for: geo.size.width))
                    .padding(.top, AppPageHeaderMetrics.height + 12)
                    .padding(.bottom, 60)
            }
            // 2. 顶部 Header (overlay 挂载)
            .overlay(alignment: .top) {
                AppPageHeader(
                    horizontalPadding: horizontalPadding(for: geo.size.width),
                    contentID: "\(gallerySnapshot.books.count)-\(gallerySnapshot.totalInventoryCount)"
                ) {
                    AppHeaderTitle("全景画廊", subtitle: "共收录 \(gallerySnapshot.books.count) 本图书")
                } trailingContent: {
                    MiniInventoryBar(totalCount: gallerySnapshot.totalInventoryCount, dataPoints: gallerySnapshot.inventoryPoints)
                        .frame(width: 320)
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
                message: "暂时没有可展示的图书",
                minHeight: 400
            )
        } else {
            let columns = [GridItem(.adaptive(minimum: currentScale.width, maximum: currentScale.width), spacing: currentScale.hSpacing)]
            LazyVGrid(columns: columns, spacing: currentScale.vSpacing) {
                ForEach(gallerySnapshot.books) { book in
                    AnimatedCardGlide(
                        book: book, gridScale: currentScale, selectedBook: $selectedBook
                    )
                    .transition(.appCardGlide)
                }
            }
        }
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        min(max(width * 0.045, 28), 56)
    }
}

#endif
