#if os(macOS)

import Charts
import SwiftData
import SwiftUI

// MARK: - 画廊全局配置

/// 统一管理画廊视图布局尺寸的常量集合。
///
/// 使用无 case 的 `enum` 作为纯粹的命名空间，防止被意外实例化。
/// 集中管理封面的宽高和网格间距，确保整个应用中的画廊比例严格一致。
public enum GalleryConfig {
    /// 封面的标准渲染宽度
    public static let coverWidth: CGFloat = 200
    /// 封面的标准渲染高度
    public static let coverHeight: CGFloat = 300
    /// 网格项之间的水平间距
    public static let horizontalSpacing: CGFloat = 32
    /// 网格项之间的垂直排版间距
    public static let verticalSpacing: CGFloat = 40
}

// MARK: - 核心全景画廊视图

/// macOS 端专属的全景画廊视图 (Archive Gallery)。
///
/// **视觉与架构设计：**
/// 该视图采用了“底层瀑布流 + 顶层悬浮磨砂 Header”的双层 Z 轴布局。
/// 支持按照“全部”、“想读”、“待读”、“已读”进行分类筛选，并带有平滑的元素增删过滤动画。
///
/// - 注意: 为了兼容 macOS 独特的红绿灯窗口控制区，顶部的 Header 设置了特定的 `.padding(.top, 45)`。
struct ArchiveGalleryView: View {
    /// 数据库中所有的书籍源数据。
    @Query var books: [Book]
    
    /// 用于处理封面点击后缩放展开到详情页的共享动画命名空间。
    let namespace: Namespace.ID
    
    /// 向上层双向绑定的选中书籍状态，一旦赋值将触发详情弹窗或转场。
    @Binding var selectedBook: Book?
    
    /// 当前正在触发共享动画的封面唯一标识符，用于规避动画过程中的重影问题。
    @Binding var activeCoverID: String
    
    /// 记录当前用户选中的分类筛选器标签，默认展示全部 ("ALL")。
    @State private var activeTab: String = "ALL"
    
    /// 经过当前 `activeTab` 过滤并排序后，实际驱动瀑布流网格渲染的书籍数组。
    @State private var displayBooks: [Book] = []
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()
                                                
                Circle()
                    .fill(Color.indigo.opacity(0.08))
                    .blur(radius: 120)
                    .frame(width: 800, height: 800)
                    .offset(x: -200, y: -300)
                
                // ================= 1. 底层滚动内容区 =================
                ScrollView {
                    gridView(containerWidth: geo.size.width)
                        .padding(.horizontal, 40)
                        // 留出原生 Header 的空间
                        .padding(.top, 140)
                        .padding(.bottom, 60)
                }
                
                // ================= 2. 顶层悬浮高定玻璃 Header =================
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        // 左侧标题组 (文字需要靠左对齐)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("全景画廊")
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)
                                            
                            Text("共收录 \(displayBooks.count) 本图书")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                                        
                        // 水平方向的撑开器
                        Spacer()
                                                                                                    
                        // 右侧：引入全新的堆叠条，宽度锁定为 280
                        MiniInventoryBar(books: books)
                            .frame(width: 280)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 45) // 完美避开 macOS 左上角的红绿灯
                    .padding(.bottom, 20)
                                    
                    // 补上底部的极简分割线，让玻璃有收边的质感
                    Divider().background(Color.primary.opacity(0.05))
                }
                // 苹果原生 Mac 顶栏材质
                .background(
                    Color.clear
                        .background(.ultraThinMaterial)
                        .opacity(0.85)
                )
                .ignoresSafeArea(edges: .top)
            }
            .onAppear { updateDisplayBooks(animate: false) }
            .onChange(of: books) { _, _ in updateDisplayBooks(animate: true) }
            .onChange(of: activeTab) { _, _ in updateDisplayBooks(animate: true) }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker(selection: $activeTab, label: EmptyView()) {
                        Text("全部书籍").tag("ALL")
                        Text("想读书籍").tag("WANT")
                        Text("待读书籍").tag("UNREAD")
                        Text("已读书籍").tag("FINISHED")
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } label: {
                    Image(systemName: activeTab == "ALL" ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                        .foregroundColor(activeTab == "ALL" ? .primary : .accentColor)
                }
                .menuIndicator(.hidden)
                .help("分类筛选")
            }
        }
    }
    
    // MARK: - 内部视图构建器
    
    @ViewBuilder
    private func gridView(containerWidth: CGFloat) -> some View {
        if displayBooks.isEmpty {
            ContentUnavailableView {
                Label(emptyStateTitle, systemImage: "books.vertical.fill")
            } description: {
                Text(emptyStateDescription)
            }
            .frame(maxWidth: .infinity, minHeight: 400)
            .transition(.opacity)
        } else {
            bookGrid(containerWidth: containerWidth)
        }
    }
    
    private var emptyStateTitle: String {
        switch activeTab {
        case "WANT": return "心愿单为空"
        case "UNREAD": return "无待读计划"
        case "FINISHED": return "暂无已读记录"
        default: return "书架空空如也"
        }
    }
    
    private var emptyStateDescription: String {
        switch activeTab {
        case "WANT": return "遇到感兴趣的书？把它标记为“想读”吧。"
        case "UNREAD": return "您目前没有正在阅读或计划阅读的书籍。"
        case "FINISHED": return "还没有读完的书籍，继续努力哦！"
        default: return "点击右上角的 \"+\" 按钮添加您的第一本书吧。"
        }
    }
    
    private func bookGrid(containerWidth: CGFloat) -> some View {
        let columns = [GridItem(.adaptive(minimum: GalleryConfig.coverWidth, maximum: GalleryConfig.coverWidth + 20), spacing: GalleryConfig.horizontalSpacing)]
        return LazyVGrid(columns: columns, spacing: GalleryConfig.verticalSpacing) {
            ForEach(displayBooks, id: \.id) { book in buildCard(for: book) }
        }
    }
    
    private func buildCard(for book: Book) -> some View {
        GalleryBookCardView(
            book: book,
            isFinishedTab: activeTab == "FINISHED",
            namespace: namespace,
            activeCoverID: activeCoverID,
            selectedBook: selectedBook
        )
        .onTapGesture {
            activeCoverID = "gallery-\(book.id ?? "")"
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { selectedBook = book }
        }
    }
    
    // MARK: - 逻辑处理
    
    /// 根据当前的分类标签 (`activeTab`) 重新计算并排序要展示的书籍列表。
    ///
    /// - 过滤逻辑：
    ///   - "WANT": 仅展示标记为想读的书，按书名字典序。
    ///   - "UNREAD": 展示待读和在读的书，按开始时间倒序。
    ///   - "FINISHED": 仅展示已读完的书，按结束时间倒序。
    ///   - "ALL": 展示全量数据，按书名字典序。
    ///
    /// - Parameter animate: 是否在刷新列表时附加 `.spring` 弹性动画。
    private func updateDisplayBooks(animate: Bool = false) {
        let updateAction = {
            switch activeTab {
            case "WANT":
                displayBooks = books.filter { $0.isWantToRead }.sorted { ($0.title ?? "") < ($1.title ?? "") }
            case "UNREAD":
                displayBooks = books.filter { $0.status == .unread || $0.status == .reading }.sorted { ($0.startTime ?? Date.distantPast) > ($1.startTime ?? Date.distantPast) }
            case "FINISHED":
                displayBooks = books.filter { $0.status == .finished }.sorted { ($0.endTime ?? Date.distantPast) > ($1.endTime ?? Date.distantPast) }
            default:
                displayBooks = books.sorted { ($0.title ?? "") < ($1.title ?? "") }
            }
        }
        if animate {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { updateAction() }
        } else {
            updateAction()
        }
    }
}
#endif
