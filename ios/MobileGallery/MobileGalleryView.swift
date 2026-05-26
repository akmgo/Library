#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 📚 主画廊视图

struct MobileGalleryView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query var allBooks: [Book]

    @State private var detailBook: Book? = nil
    @State private var filterStatus: BookStatus? = nil
    @State private var sortKey: BookGallerySortKey = .newest
    @State private var gridScale: Int = 1
    @State private var isEditing = false
    @State private var selectedIDs: Set<String> = []
    @State private var showBatchDeleteAlert = false
    @State private var showAddBook = false

    var isLandscape: Bool { verticalSizeClass == .compact }

    var processedBooks: [Book] {
        ReadingStatsCalculator.bookGallerySnapshot(
            books: allBooks,
            filterStatus: filterStatus,
            searchText: "",
            sortKey: sortKey
        ).books
    }

    private var gridItemSize: CGFloat {
        let base: CGFloat = isLandscape ? 100 : 80
        return base + CGFloat(gridScale) * 24
    }

    private var galleryStats: [PageStatItemData] {
        let total = allBooks.count
        let readingCount = allBooks.filter { $0.status == .reading }.count
        let finishedCount = allBooks.filter { $0.status == .finished }.count
        let abandonedCount = allBooks.filter { $0.status == .abandoned }.count
        let completionRate = (finishedCount + abandonedCount) > 0
            ? Int(Double(finishedCount) / Double(finishedCount + abandonedCount) * 100)
            : 0

        return [
            PageStatItemData(title: "全部馆藏", value: "\(total)", color: .indigo),
            PageStatItemData(title: "在读", value: "\(readingCount)", color: AppColors.readingAmber),
            PageStatItemData(title: "已读完", value: "\(finishedCount)", color: .teal),
            PageStatItemData(title: "读完率", value: "\(completionRate)", color: .pink),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: AppSpacing.m) {
                    MobilePageStatsHeader(items: galleryStats)

                if processedBooks.isEmpty {
                    emptyStateView
                } else {
                        let size = gridItemSize
                        let spacing: CGFloat = isLandscape ? 20 : 16
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: size, maximum: size + 48), spacing: spacing)], spacing: isLandscape ? 24 : 22) {
                            ForEach(processedBooks, id: \.id) { book in
                                ZStack(alignment: .topTrailing) {
                                    Button(action: {
                                        if isEditing {
                                            toggleSelection(book.id)
                                        } else {
                                            detailBook = book
                                        }
                                    }) {
                                        MobileBookGridCell(book: book)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous)
                                                    .stroke(isEditing && selectedIDs.contains(book.id) ? Color.blue : Color.clear, lineWidth: 3)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, isLandscape ? 28 : 18)
                        .padding(.bottom, AppSpacing.emptyState)
                }
                }
            }
            .background(AppColors.primaryBackground(for: colorScheme).ignoresSafeArea())
            .navigationDestination(item: $detailBook) { book in MobileBookDetailView(book: book) }
            .toolbar { galleryToolbar }
            .sheet(isPresented: $showAddBook) {
                MobileBookSearchSheet(isPresented: $showAddBook)
            }
            .alert("批量删除", isPresented: $showBatchDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive, action: batchDelete)
            } message: {
                Text("确定删除选中的 \(selectedIDs.count) 本书籍吗？此操作不可撤销。")
            }
        }
    }

    @ToolbarContentBuilder
    private var galleryToolbar: some ToolbarContent {
        if isEditing {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 16) {
                    Button("取消") { withAnimation { exitEditMode() } }
                    if !selectedIDs.isEmpty {
                        Text("\(selectedIDs.count)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            if !selectedIDs.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showBatchDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(AppColors.danger)
                    }
                }
            }
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 14) {
                    Button(action: {
                        withAnimation { isEditing = true }
                    }) {
                        Image(systemName: "checklist")
                    }

                    Menu {
                        Button(action: { filterStatus = nil }) {
                            HStack {
                                Text("全部")
                                if filterStatus == nil { Image(systemName: "checkmark") }
                            }
                        }
                        ForEach(BookStatus.allCases, id: \.self) { status in
                            Button(action: { filterStatus = status }) {
                                HStack {
                                    Text(status.displayName)
                                    if filterStatus == status { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }

                    Menu {
                        ForEach(BookGallerySortKey.allCases, id: \.self) { key in
                            Button(action: { sortKey = key }) {
                                HStack {
                                    Text(key.displayName)
                                    if sortKey == key { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }

                    Menu {
                        Button(action: { gridScale = 0 }) {
                            HStack {
                                Text("小")
                                if gridScale == 0 { Image(systemName: "checkmark") }
                            }
                        }
                        Button(action: { gridScale = 1 }) {
                            HStack {
                                Text("中")
                                if gridScale == 1 { Image(systemName: "checkmark") }
                            }
                        }
                        Button(action: { gridScale = 2 }) {
                            HStack {
                                Text("大")
                                if gridScale == 2 { Image(systemName: "checkmark") }
                            }
                        }
                    } label: {
                        Image(systemName: "rectangle.grid.2x2")
                    }

                    Button(action: { showAddBook = true }) {
                        Image(systemName: "plus")
                    }
                }
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

    // MARK: - 批量操作

    private func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) }
        else { selectedIDs.insert(id) }
    }

    private func exitEditMode() {
        isEditing = false
        selectedIDs = []
    }

    private func batchDelete() {
        let targets = allBooks.filter { selectedIDs.contains($0.id) }
        try? ReadingDataService.shared.deleteBooks(targets, context: modelContext)
        exitEditMode()
    }

    private func batchChangeStatus(to status: BookStatus) {
        let targets = allBooks.filter { selectedIDs.contains($0.id) }
        for book in targets {
            try? ReadingDataService.shared.updateStatus(book, to: status, context: modelContext)
        }
        exitEditMode()
    }
}

// MARK: - 📱 单本书籍网格卡片

struct MobileBookGridCell: View {
    let book: Book

    var body: some View {
        BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
            .aspectRatio(2 / 3, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
            .shadow(color: Color.black.opacity(0.10), radius: 6, y: 3)
            .contentShape(Rectangle())
    }
}


#if DEBUG
#Preview("画廊") {
    PreviewWithData {
        MobileGalleryView()
    }
}
#endif


#endif
