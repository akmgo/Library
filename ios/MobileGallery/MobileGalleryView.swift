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
        let filtered = allBooks.filter { book in
            return selectedFilter == .all || book.status == selectedFilter.targetStatus
        }
        
        return filtered.sorted { b1, b2 in
            let result: Bool
            switch sortType {
            case .dateAdded:
                result = b1.createdAt < b2.createdAt
            case .lastRead:
                let d1 = b1.lastReadAt ?? b1.startDate ?? b1.createdAt
                let d2 = b2.lastReadAt ?? b2.startDate ?? b2.createdAt
                result = d1 < d2
            case .progress:
                result = b1.progressRatio < b2.progressRatio
            case .title:
                result = b1.title.localizedStandardCompare(b2.title) == .orderedAscending
            }
            return isAscending ? result : !result
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if processedBooks.isEmpty {
                    emptyStateView
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        let minWidth: CGFloat = isLandscape ? 140 : 105
                        let maxWidth: CGFloat = isLandscape ? 200 : 160
                        let gridSpacing: CGFloat = isLandscape ? 28 : 20
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: minWidth, maximum: maxWidth), spacing: gridSpacing)], spacing: 32) {
                            ForEach(processedBooks, id: \.id) { book in
                                if isBatchEditing {
                                    // 批量编辑模式
                                    Button(action: { toggleSelection(for: book.id) }) {
                                        MobileBookGridCell(
                                            book: book,
                                            showProgress: selectedFilter == .reading,
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
                                            showProgress: selectedFilter == .reading,
                                            isEditing: false,
                                            isSelected: false,
                                            onDetailTap: {
                                                // 触发菜单栏选项：进入详情
                                                detailBook = book
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 120)
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: processedBooks)
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
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "books.vertical").font(.system(size: 56)).foregroundColor(.secondary.opacity(0.4))
            Text("这里还没有书籍记录哦").font(.system(size: 18, weight: .bold)).foregroundColor(.secondary)
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private func toggleSelection(for id: String) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if selectedBooks.contains(id) { selectedBooks.remove(id) } else { selectedBooks.insert(id) }
    }
    
    private func deleteSelectedBooks() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        for book in allBooks where selectedBooks.contains(book.id) { modelContext.delete(book) }
        try? modelContext.save()
        selectedBooks.removeAll()
        isBatchEditing = false
        NotificationCenter.default.post(name: .libraryDidUpdate, object: nil)
    }
}

// MARK: - 📱 单本书籍网格卡片

struct MobileBookGridCell: View {
    let book: Book
    var showProgress: Bool = false
    var isEditing: Bool = false
    var isSelected: Bool = false
    
    // ✨ 菜单点击事件回调
    var onDetailTap: (() -> Void)? = nil
    
    var body: some View {
        let safeTitle = book.title
        let safeAuthor = book.author
        let safeStatus = book.status
        
        VStack(alignment: .leading, spacing: 12) {
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
                
                if showProgress && safeStatus == .reading {
                    Text("\(Int(book.progressRatio * 100))%")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(Color.blue.opacity(0.9).background(.ultraThinMaterial))
                        .clipShape(Capsule())
                        .offset(x: -8, y: 8)
                }
                
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
            
            // ================= 2. 底部信息与菜单区 =================
            HStack(alignment: .top, spacing: 4) {
                // 左侧书名与作者
                VStack(alignment: .leading, spacing: 4) {
                    Text(safeTitle).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.primary).lineLimit(1)
                    Text(safeAuthor).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // ✨ 移到外部右下角的详情菜单
                if !isEditing {
                    Menu {
                        Button(action: {
                            onDetailTap?()
                        }) {
                            Label("书籍详情", systemImage: "info.circle")
                        }
                        // 未来可以加分享、加标签等快捷按钮
                    } label: {
                        // 适应页面背景的极简风格
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.6))
                            // 扩大点击热区，避免误触跳转阅读器
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    // 消除自带的系统点击高亮抖动
                    .buttonStyle(.plain)
                    // 微调位置，使其在视觉上与第一行书名完美居中对齐
                    .offset(y: -2)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

#endif
