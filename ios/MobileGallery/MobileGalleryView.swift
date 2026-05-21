#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 📚 主画廊视图

struct MobileGalleryView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Query var allBooks: [Book]
    
    @State private var detailBook: Book? = nil
    
    var isLandscape: Bool { verticalSizeClass == .compact }
    
    /// 核心引擎：在内存中一条龙完成 [过滤] -> [排序]
    var processedBooks: [Book] {
        ReadingStatsCalculator.bookGallerySnapshot(
            books: allBooks,
            filterStatus: nil,
            searchText: "",
            sortKey: .newest
        ).books
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if processedBooks.isEmpty {
                    emptyStateView
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        let minWidth: CGFloat = isLandscape ? 118 : 96
                        let maxWidth: CGFloat = isLandscape ? 154 : 124
                        let gridSpacing: CGFloat = isLandscape ? 20 : 16
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: minWidth, maximum: maxWidth), spacing: gridSpacing)], spacing: isLandscape ? 24 : 22) {
                            ForEach(processedBooks, id: \.id) { book in
                                Button(action: {
                                    detailBook = book
                                }) {
                                    MobileBookGridCell(book: book)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, isLandscape ? 28 : 18)
                        .padding(.top, 16)
                        .padding(.bottom, 120)
                    }
                }
            }
            .background(AppColors.primaryBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle("全景画廊")
            .navigationBarTitleDisplayMode(.large)
            // ✨ 统一收口 1：推入书籍详情页
            .navigationDestination(item: $detailBook) { book in
                MobileBookDetailView(book: book)
            }
        }
    }
    
    private var emptyStateView: some View {
        EmptyStateView(
            systemImage: "books.vertical",
            title: "这里还没有书籍记录哦",
            message: "添加第一本书后，画廊会在这里展开。",
            iconSize: 56
        )
    }
    
}

// MARK: - 📱 单本书籍网格卡片

struct MobileBookGridCell: View {
    let book: Book
    
    var body: some View {
        let safeTitle = book.title
        
        VStack(spacing: 0) {
            // ================= 1. 顶部纯净封面区 =================
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .overlay(BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: safeTitle).scaledToFill())
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.3), location: 0.0),
                                .init(color: .white.opacity(0.0), location: 0.08)
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
                    )
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.bookCover).stroke(Color.black.opacity(0.1), lineWidth: 0.5))

            }
        }
        .contentShape(Rectangle())
    }
}

#endif
