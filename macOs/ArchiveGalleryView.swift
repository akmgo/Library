#if os(macOS)

import Charts
import SwiftData
import SwiftUI

/// 统一的画廊配置常量
public enum GalleryConfig {
    public static let coverWidth: CGFloat = 200
    public static let coverHeight: CGFloat = 300
    public static let horizontalSpacing: CGFloat = 32
    public static let verticalSpacing: CGFloat = 40
}

struct ArchiveGalleryView: View {
    @Query var books: [Book]
    let namespace: Namespace.ID
    @Binding var selectedBook: Book?
    @Binding var activeCoverID: String
    @State private var activeTab: String = "ALL"
    
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
                    // ✨ 修复：这里必须是 HStack，才能实现左标题、右数据的水平两端对齐
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
                                        
                        // ✨ 水平方向的撑开器
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
                // ✨ 苹果原生 Mac 顶栏材质
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
    
    private func updateDisplayBooks(animate: Bool = false) {
        let updateAction = {
            switch activeTab {
            case "WANT":
                displayBooks = books.filter { $0.isWantToRead }.sorted { ($0.title ?? "") < ($1.title ?? "") }
            case "UNREAD":
                // ✨ 修复：使用枚举进行比较
                displayBooks = books.filter { $0.status == .unread || $0.status == .reading }.sorted { ($0.startTime ?? Date.distantPast) > ($1.startTime ?? Date.distantPast) }
            case "FINISHED":
                // ✨ 修复
                displayBooks = books.filter { $0.status == .finished }.sorted { ($0.endTime ?? Date.distantPast) > ($1.endTime ?? Date.distantPast) }
            default:
                displayBooks = books.sorted { ($0.title ?? "") < ($1.title ?? "") }
            }
        }
        if animate { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { updateAction() } }
        else { updateAction() }
    }
}

struct GalleryBookCardView: View {
    let book: Book
    let isFinishedTab: Bool
    let namespace: Namespace.ID
    let activeCoverID: String
    let selectedBook: Book?
    
    @State private var isHovered = false
    let ratingTexts = ["", "一星毒草", "二星平庸", "三星粮草", "四星推荐", "🔥 改变人生"]
    
    var body: some View {
        let safeTitle = book.title ?? "未知书名"
        let safeAuthor = book.author ?? "未知作者"
        
        VStack(alignment: .leading, spacing: 12) {
            // ✨ 封面区：绝对工整的尺寸控制
            LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                .frame(width: GalleryConfig.coverWidth, height: GalleryConfig.coverHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                // macOS 原生阴影配方
                .shadow(color: Color.black.opacity(isHovered ? 0.2 : 0.08), radius: isHovered ? 12 : 4, y: isHovered ? 6 : 2)
                // 封面悬浮放大 (要求保留)
                .scaleEffect(isHovered ? 1.03 : 1.0)
                // 悬浮时略微上浮
                .offset(y: isHovered ? -4 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
                // 精致的原生反光边框
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
            
            // 信息区
            VStack(alignment: .leading, spacing: 4) {
                Text(safeTitle)
                    .font(.system(size: 15, weight: .bold))
                    // 悬浮时标题高亮为系统强调色，否则为主文字色
                    .foregroundColor(isHovered ? .accentColor : .primary)
                    .lineLimit(1)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                
                Text(safeAuthor)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if isFinishedTab && book.status == .finished {
                    GalleryStatsView(book: book, ratingTexts: ratingTexts)
                        .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
            // 锁定信息区宽度与封面一致，确保绝对对齐
            .frame(width: GalleryConfig.coverWidth, height: isFinishedTab ? 110 : 40, alignment: .topLeading)
        }
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { isHovered = h } }
        .onChange(of: selectedBook) { _, newValue in if newValue != nil { isHovered = false } }
    }
}

// MARK: - 已读统计详情组件

private struct GalleryStatsView: View {
    let book: Book
    let ratingTexts: [String]
    
    var body: some View {
        let safeRating = book.rating ?? 0
        let safeTags = book.tags ?? []

        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.top, 4)
            
            // 评分行
            HStack(alignment: .center) {
                HStack(spacing: 2) {
                    if safeRating > 0 {
                        ForEach(1 ... 5, id: \.self) { i in
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(i <= safeRating ? .yellow : Color.secondary.opacity(0.2))
                        }
                    } else {
                        Text("暂无评分").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary.opacity(0.6))
                    }
                }
                Spacer()
                if safeRating > 0 && safeRating < ratingTexts.count {
                    Text(ratingTexts[safeRating])
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                }
            }
            
            // 日期与历时行
            HStack(alignment: .center) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.system(size: 10))
                    Text("\(formatShortDate(book.startTime)) - \(formatShortDate(book.endTime))")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                Text("历时 \(calculateDays(start: book.startTime, end: book.endTime)) 天")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            // 标签行
            if !safeTags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(safeTags.prefix(3)), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            // Mac 原生底色，自带系统级别的深浅控制
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    }
                }
                .padding(.top, 2)
            }
        }
    }
    
    private func formatShortDate(_ date: Date?) -> String {
        guard let d = date else { return "?" }
        let formatter = DateFormatter(); formatter.dateFormat = "yy/MM/dd"; return formatter.string(from: d)
    }

    private func calculateDays(start: Date?, end: Date?) -> Int {
        guard let s = start, let e = end else { return 1 }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: s)
        let endOfDay = calendar.startOfDay(for: e)
        let diff = calendar.dateComponents([.day], from: startOfDay, to: endOfDay).day ?? 0
        return max(1, diff + 1)
    }
}

// MARK: - ✨ 画廊专属：迷你库存堆叠条 (修复编译报错版)
private struct MiniInventoryBar: View {
    let books: [Book]
    
    // 💡 将复杂的 for 循环和判断逻辑抽离到计算属性中，保持 body 的纯净
    private var inventoryData: (total: Int, stats: [(label: String, count: Int, color: Color)]) {
        var finished = 0
        var reading = 0
        var want = 0
        var unread = 0
        
        // 互斥排他逻辑
        for book in books {
            if book.status == .finished {
                finished += 1
            } else if book.status == .reading {
                reading += 1
            } else if book.isWantToRead {
                want += 1
            } else {
                unread += 1
            }
        }
        
        // 过滤掉数量为 0 的项目
        let filteredStats: [(label: String, count: Int, color: Color)] = [
            ("已读", finished, .indigo),
            ("在读", reading, .blue),
            ("未读", unread, .gray),
            ("心愿", want, .orange)
        ].filter { $0.count > 0 }
        
        let totalCount = filteredStats.reduce(0) { $0 + $1.count }
        
        return (totalCount, filteredStats)
    }
    
    var body: some View {
        // 在 body 顶部安全地提取算好的数据
        let total = inventoryData.total
        let stats = inventoryData.stats
        
        VStack(alignment: .trailing, spacing: 8) { // 整体靠右对齐
            // 上方：极简的标签与数字
            HStack(spacing: 12) {
                if total == 0 {
                    Text("书库为空").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                } else {
                    ForEach(stats, id: \.label) { stat in
                        HStack(spacing: 4) {
                            Circle().fill(stat.color).frame(width: 6, height: 6)
                            Text("\(stat.count)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.primary)
                            Text(stat.label).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // 下方：堆叠条形图
            GeometryReader { geo in
                HStack(spacing: 2) { // 间距 2pt，极其锋利
                    if total == 0 {
                        Rectangle().fill(Color.secondary.opacity(0.1)).cornerRadius(3)
                    } else {
                        ForEach(stats, id: \.label) { stat in
                            // 根据准确的比例计算每一截的宽度
                            let width = max(0, (CGFloat(stat.count) / CGFloat(total)) * geo.size.width - 2)
                            Rectangle()
                                .fill(stat.color.opacity(0.8))
                                .frame(width: width)
                                .cornerRadius(3)
                        }
                    }
                }
            }
            .frame(height: 6) // 高度只有 6pt，极度克制
        }
    }
}
#endif
