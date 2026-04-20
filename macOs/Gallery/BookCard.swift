#if os(macOS)

import SwiftUI
import SwiftData

// MARK: - 画廊实体卡片

/// 画廊网格中的单本书籍渲染卡片。
///
/// 包含标准比例的封面视图、标题、作者以及特定的交互动效（鼠标悬停放大、系统原生的微弱反光边框）。
/// 当画廊处于“已读书籍”分类时，它会额外在其底部展开一个展示打分与阅读历时的统计小面板。
struct GalleryBookCardView: View {
    let book: Book
    
    /// 标志位：控制是否需要渲染底部的评分与日期视图。
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
            // 封面区：绝对工整的尺寸控制
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

/// 仅在“已读”面板中展示的书籍附加元数据视图。
///
/// 渲染书籍的星级评分、阅读历时（开始到结束的天数）以及前三个关联标签。
struct GalleryStatsView: View {
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
    
    // MARK: - 数据处理辅助方法
    
    /// 将日期对象格式化为极简短字符串形式 (`yy/MM/dd`)。
    ///
    /// - Parameter date: 需要格式化的日期对象。
    /// - Returns: 若传入 `nil` 则返回 `?`，否则返回短日期字符串。
    private func formatShortDate(_ date: Date?) -> String {
        guard let d = date else { return "?" }
        let formatter = DateFormatter(); formatter.dateFormat = "yy/MM/dd"; return formatter.string(from: d)
    }

    /// 计算阅读开始与结束日期之间的跨越天数。
    ///
    /// 此算法采用 `Calendar.startOfDay` 进行自然日对齐计算，哪怕跨越午夜 1 秒也会计入为 2 天。
    ///
    /// - Parameters:
    ///   - start: 阅读起始时间。
    ///   - end: 阅读终止时间。
    ///
    /// - Returns: 经过底线防御的安全天数，最少为 1 天。
    private func calculateDays(start: Date?, end: Date?) -> Int {
        guard let s = start, let e = end else { return 1 }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: s)
        let endOfDay = calendar.startOfDay(for: e)
        let diff = calendar.dateComponents([.day], from: startOfDay, to: endOfDay).day ?? 0
        return max(1, diff + 1)
    }
}
#endif
