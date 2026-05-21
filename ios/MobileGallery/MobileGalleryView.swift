#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 🎨 画廊专属筛选枚举

enum GalleryFilter: String, CaseIterable, CustomStringConvertible {
    case all = "全部书籍"
    case reading = "正在阅读"
    case planned = "想要阅读"
    case unread = "尚未开始"
    case finished = "已经读完"
    case abandoned = "不再阅读"
    
    var description: String { self.rawValue }
    
    var targetStatus: BookStatus? {
        switch self {
        case .all: return nil
        case .reading: return .reading
        case .planned: return .planned
        case .unread: return .unread
        case .finished: return .finished
        case .abandoned: return .abandoned
        }
    }
}

// MARK: - 🗂️ 排序逻辑引擎

enum GallerySortType: String, CaseIterable, Identifiable {
    case lastRead = "最近阅读"
    case dateAdded = "入库时间"
    case progress = "阅读进度"
    case title = "书名排序"
    
    var id: String { self.rawValue }
}

// MARK: - 📚 主画廊视图

struct MobileGalleryView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query var allBooks: [Book]
    
    // 🔍 状态池
    @State private var selectedFilter: GalleryFilter = .all
    @State private var sortType: GallerySortType = .lastRead
    @State private var isAscending: Bool = false
    
    // 🗑️ 批量管理状态
    @State private var isBatchEditing = false
    @State private var selectedBooks = Set<String>()
    
    @State private var detailBook: Book? = nil
    
    var isLandscape: Bool { verticalSizeClass == .compact }
    
    /// 核心引擎：在内存中一条龙完成 [过滤] -> [排序]
    var processedBooks: [Book] {
        ReadingStatsCalculator.bookGallerySnapshot(
            books: allBooks,
            filterStatus: selectedFilter.targetStatus,
            searchText: "",
            sortKey: sortType.gallerySortKey,
            ascending: isAscending
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
                                if isBatchEditing {
                                    // 批量编辑模式
                                    Button(action: { toggleSelection(for: book.id) }) {
                                        MobileBookGridCell(
                                            book: book,
                                            isEditing: true,
                                            isSelected: selectedBooks.contains(book.id)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Button(action: {
                                        detailBook = book
                                    }) {
                                        MobileBookGridCell(
                                            book: book,
                                            isEditing: false,
                                            isSelected: false
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, isLandscape ? 28 : 18)
                        .padding(.top, 16)
                        .padding(.bottom, 120)
                    }
                }
            }
            .background(AppColors.primaryBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle(selectedFilter.rawValue)
            .navigationBarTitleDisplayMode(.large)
            
            // 批量操作栏
            .safeAreaInset(edge: .bottom) {
                if isBatchEditing {
                    batchActionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onChange(of: isBatchEditing) { _, newValue in
                if !newValue { selectedBooks.removeAll() }
            }
            
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    MobileBatchEditToggleButton(isEditing: $isBatchEditing)
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        MobileFilterMenuButton(
                            selection: $selectedFilter,
                            options: GalleryFilter.allCases,
                            activeIcon: "line.3.horizontal.decrease.circle.fill",
                            inactiveIcon: "line.3.horizontal.decrease.circle",
                            isFiltered: selectedFilter != .all
                        )
                        MobileSortMenuButton(
                            selection: $sortType,
                            options: GallerySortType.allCases,
                            isAscending: $isAscending
                        )
                    }
                }
            }
            // ✨ 统一收口 1：推入书籍详情页
            .navigationDestination(item: $detailBook) { book in
                MobileBookDetailView(book: book)
            }
        }
    }
    
    // ... batchActionBar, emptyStateView, toggleSelection, deleteSelectedBooks 保持你的原样 ...
    private var batchActionBar: some View {
        HStack {
            Button(action: {
                if selectedBooks.count == processedBooks.count {
                    selectedBooks.removeAll()
                } else {
                    selectedBooks = Set(processedBooks.map { $0.id })
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                Text(selectedBooks.count == processedBooks.count ? "取消全选" : "全选")
                    .font(.system(size: 16, weight: .medium))
            }
            Spacer()
            Text("已选择 \(selectedBooks.count) 项")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
            Button(role: .destructive, action: deleteSelectedBooks) {
                Text("删除").font(.system(size: 16, weight: .bold))
            }
            .disabled(selectedBooks.isEmpty)
        }
        .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 16)
        .background(.regularMaterial)
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(.secondary.opacity(0.2)), alignment: .top)
    }
    
    private var emptyStateView: some View {
        EmptyStateView(
            systemImage: "books.vertical",
            title: "这里还没有书籍记录哦",
            message: "添加第一本书后，画廊会在这里展开。",
            iconSize: 56
        )
    }
    
    private func toggleSelection(for id: String) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if selectedBooks.contains(id) { selectedBooks.remove(id) } else { selectedBooks.insert(id) }
    }
    
    private func deleteSelectedBooks() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        let booksToDelete = allBooks.filter { selectedBooks.contains($0.id) }
        try? ReadingDataService.shared.deleteBooks(booksToDelete, context: modelContext)
        selectedBooks.removeAll()
        isBatchEditing = false
    }
}

extension GallerySortType {
    var gallerySortKey: BookGallerySortKey {
        switch self {
        case .lastRead:
            return .lastRead
        case .dateAdded:
            return .dateAdded
        case .progress:
            return .progress
        case .title:
            return .title
        }
    }
}

// MARK: - 📱 单本书籍网格卡片

struct MobileBookGridCell: View {
    let book: Book
    var isEditing: Bool = false
    var isSelected: Bool = false
    
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

                if isEditing {
                    ZStack {
                        Color.black.opacity(isSelected ? 0.1 : 0.4)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
                        
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(isSelected ? .blue : .white.opacity(0.8))
                                    .background(Circle().fill(isSelected ? Color.white : Color.clear).frame(width: 22, height: 22))
                                    .padding(8)
                            }
                        }
                    }
                }
            }
            .opacity(isEditing && !isSelected ? 0.8 : 1.0)
        }
        .contentShape(Rectangle())
    }
}

#endif
