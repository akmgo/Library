#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 🎨 画廊专属筛选枚举 (彻底消灭魔法字符串)
enum GalleryFilter: String, CaseIterable {
    case all = "全部"
    case reading = "在读"
    case unread = "待读"
    case finished = "已读"
    
    // 映射到底层的 BookStatus
    var targetStatus: BookStatus? {
        switch self {
        case .all: return nil
        case .reading: return .reading
        case .unread: return .unread
        case .finished: return .finished
        }
    }
}

// MARK: - 📚 主画廊视图
struct MobileGalleryView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Query var allBooks: [Book]
    
    @State private var searchText = ""
    @State private var selectedFilter: GalleryFilter = .all
    
    var isLandscape: Bool { verticalSizeClass == .compact }
    
    // ✨ 极致安全与高效的内存过滤逻辑
    var filteredBooks: [Book] {
        allBooks.filter { book in
            let safeTitle = book.title ?? ""
            let safeAuthor = book.author ?? ""
            
            // 1. 搜索匹配
            let matchSearch = searchText.isEmpty ||
                              safeTitle.localizedCaseInsensitiveContains(searchText) ||
                              safeAuthor.localizedCaseInsensitiveContains(searchText)
            
            // 2. 状态匹配 (枚举级别的安全比对)
            let matchStatus = selectedFilter == .all || book.status == selectedFilter.targetStatus
            
            return matchSearch && matchStatus
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部筛选栏
                filterBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .padding(.top, 8)
                
                if filteredBooks.isEmpty {
                    emptyStateView
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                                            let minWidth: CGFloat = isLandscape ? 140 : 105
                                            let maxWidth: CGFloat = isLandscape ? 200 : 160
                                            let gridSpacing: CGFloat = isLandscape ? 28 : 20
                                            
                                            LazyVGrid(columns: [GridItem(.adaptive(minimum: minWidth, maximum: maxWidth), spacing: gridSpacing)], spacing: 32) {
                                                ForEach(filteredBooks, id: \.id) { book in
                                                    NavigationLink(destination: MobileBookDetailView(book: book)) {
                                                        // ✨ 核心逻辑：只在选中“在读”标签时，才告诉卡片显示进度条
                                                        MobileBookGridCell(book: book, showProgress: selectedFilter == .reading)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .padding(.horizontal, 20)
                                            .padding(.top, 16)
                                            .padding(.bottom, 120)
                                        }
                                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filteredBooks)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("我的藏书")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "搜索书名或作者")
        }
    }
    
    // MARK: - 辅助组件
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(GalleryFilter.allCases, id: \.self) { filter in
                    MobileFilterChip(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "books.vertical" : "magnifyingglass")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.4))
            
            Text(searchText.isEmpty ? "这个分类下还没有书哦" : "找不到相关书籍")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.secondary)
            
            Text(searchText.isEmpty ? "去首页点击右上角添置新书吧" : "换个搜索词试试")
                .font(.system(size: 14))
                .foregroundColor(Color.gray.opacity(0.5))
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 📱 单本书籍网格卡片 (注入物理质感 + 智能进度显示)
struct MobileBookGridCell: View {
    let book: Book
    var showProgress: Bool = false // ✨ 新增控制开关
    
    var body: some View {
        let safeTitle = book.title ?? "未知书名"
        let safeAuthor = book.author ?? "未知作者"
        let safeStatus = book.status ?? .unread
        
        VStack(alignment: .leading, spacing: 12) {
            // ================= 1. 封面与物理质感 =================
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .overlay(LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle).scaledToFill())
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                    .overlay(
                        // 🍏 书脊高光效果保留，质感拉满
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.3), location: 0.0),
                                .init(color: .white.opacity(0.0), location: 0.08)
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.1), lineWidth: 0.5))
                
                // ================= 2. 状态微标 (Badge) =================
                // ✨ 只有在开关打开，且书本真的是在读状态时才显示（彻底移除了已读的打勾标志）
                if showProgress && safeStatus == .reading {
                    Text("\(book.progress)%")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.9).background(.ultraThinMaterial))
                        .clipShape(Capsule())
                        .offset(x: -8, y: 8)
                }
            }
            
            // ================= 3. 信息文本 =================
            VStack(alignment: .leading, spacing: 4) {
                Text(safeTitle)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(safeAuthor)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - 📱 过滤胶囊
struct MobileFilterChip: View {
    let title: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { action() }
        }) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 18).padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(uiColor: .secondarySystemGroupedBackground))
                .foregroundColor(isSelected ? .white : .secondary)
                .clipShape(Capsule())
                // 💡 微调未选中的边框，让它在浅色深色下都很融洽
                .overlay(Capsule().stroke(isSelected ? .clear : Color.primary.opacity(0.08), lineWidth: 1))
        }
    }
}
#endif
