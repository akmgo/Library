#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

// MARK: - 🎛️ 离散式网格缩放引擎

enum GalleryGridScale: Double, CaseIterable {
    case small = 0.0; case medium = 1.0; case large = 2.0; case extraLarge = 3.0
    var displayName: String {
        switch self {
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        case .extraLarge: return "特大"
        }
    }

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

struct BookGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedBook: Book?
    let filterStatus: BookStatus?
    let sortKey: BookGallerySortKey
    let gridScale: GalleryGridScale
    @Binding var isBatchDeletePresented: Bool
    @Binding var selectedBookIDs: Set<String>
    @Query private var allBooks: [Book]
    @State private var gallerySnapshot: ReadingStatsCalculator.BookGallerySnapshot?
    @State private var galleryHeaderStats: [PageStatItemData] = []

    private var galleryFP: String {
        "\(allBooks.count)-\(filterStatus?.rawValue ?? "")-\(sortKey)"
    }
    
    var body: some View {
        GeometryReader { geo in
            // 1. 主体滚动区
            ScrollView {
                gridView(containerWidth: geo.size.width)
                    .padding(.top, AppPageHeaderMetrics.height + 12)
                    .padding(.bottom, 60)
            }
            .onAppear { refreshGalleryData() }
            .onChange(of: galleryFP) { _, _ in refreshGalleryData() }
            // 2. 顶部 Header (overlay 挂载)
            .overlay(alignment: .top) {
                AppPageHeader(
                    contentID: "\(gallerySnapshot?.books.count ?? 0)-\(gallerySnapshot?.totalInventoryCount ?? 0)-\(filterStatus?.rawValue ?? "all")-\(sortKey)"
                ) {
                    AppHeaderTitle("全景画廊", subtitle: "你的阅读对象与状态总览。")
            } trailingContent: { PageStatsCompact(items: galleryHeaderStats) }
            }
            .overlay(alignment: .bottom) {
                if isBatchDeletePresented {
                    galleryBatchDeleteCapsule
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
    
    @ViewBuilder
    private func gridView(containerWidth: CGFloat) -> some View {
        if let snapshot = gallerySnapshot, !snapshot.books.isEmpty {
            let columns = [GridItem(.adaptive(minimum: gridScale.width, maximum: gridScale.width), spacing: gridScale.hSpacing)]
            LazyVGrid(columns: columns, spacing: gridScale.vSpacing) {
                ForEach(snapshot.books) { book in
                    AnimatedCardGlide(
                        book: book,
                        gridScale: gridScale,
                        selectedBook: $selectedBook,
                        isBatchMode: isBatchDeletePresented,
                        isSelected: selectedBookIDs.contains(book.id),
                        onToggleSelection: { toggleSelection(for: book) }
                    )
                }
            }
        } else if gallerySnapshot != nil {
            EmptyStateView(
                systemImage: "books.vertical.fill",
                title: "没有找到相关书籍",
                message: "暂时没有可展示的图书",
                minHeight: 400
            )
        }
    }

    private var selectedBooks: [Book] {
        allBooks.filter { selectedBookIDs.contains($0.id) }
    }

    private var galleryBatchDeleteCapsule: some View {
        HStack(spacing: 14) {
            Button {
                withAnimation(.appContentFade) {
                    selectedBookIDs.removeAll()
                    isBatchDeletePresented = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("取消")

            Text("已选择 \(selectedBookIDs.count) 本")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(minWidth: 88)

            Button(role: .destructive) {
                deleteSelectedBooks()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(selectedBookIDs.isEmpty)
            .help("删除")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .appCapsuleStyle(tint: AppColors.readingAmber, fillOpacity: 0.12, strokeOpacity: 0.10)
    }

    private func refreshGalleryData() {
        let snapshot = ReadingStatsCalculator.bookGallerySnapshot(
            books: allBooks, filterStatus: filterStatus, searchText: "", sortKey: sortKey
        )
        gallerySnapshot = snapshot
        let counts = Dictionary(grouping: allBooks, by: \.status).mapValues(\.count)
        let finished = counts[.finished] ?? 0
        let abandoned = counts[.abandoned] ?? 0
        let rate = (finished + abandoned) > 0
            ? Int(Double(finished) / Double(finished + abandoned) * 100) : 0
        galleryHeaderStats = [
            PageStatItemData(title: "全部馆藏", value: "\(allBooks.count)", color: .indigo),
            PageStatItemData(title: "在读", value: "\(counts[.reading] ?? 0)", color: AppColors.readingAmber),
            PageStatItemData(title: "已读完", value: "\(finished)", color: .teal),
            PageStatItemData(title: "读完率", value: "\(rate)", color: .pink),
        ]
    }

    private func toggleSelection(for book: Book) {
        withAnimation(.appControlFeedback) {
            if selectedBookIDs.contains(book.id) {
                selectedBookIDs.remove(book.id)
            } else {
                selectedBookIDs.insert(book.id)
            }
        }
    }

    private func deleteSelectedBooks() {
        do {
            try ReadingDataService.shared.deleteBooks(selectedBooks, context: modelContext)
            withAnimation(.appContentFade) {
                selectedBookIDs.removeAll()
                isBatchDeletePresented = false
            }
        } catch {
        }
    }
}

#endif
