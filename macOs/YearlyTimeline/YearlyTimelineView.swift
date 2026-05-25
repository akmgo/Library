#if os(macOS)
import SwiftData
import SwiftUI
import AppKit

// MARK: - ✨ 年度阅读轨迹主视图

struct YearlyTimelineView: View {
    @Binding var selectedBook: Book?
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @Query(sort: \ReadingSession.date, order: .reverse) private var sessions: [ReadingSession]
    
    @Binding var selectedYear: Int
    @Binding var availableYears: [Int]
    
    @State private var previousYear: Int = Calendar.current.component(.year, from: Date())

    private var yearlySnapshot: ReadingStatsCalculator.YearlyArchiveSnapshot {
        ReadingStatsCalculator.yearlyArchiveSnapshot(
            books: books,
            sessions: sessions,
            selectedYear: selectedYear
        )
    }
    
    var body: some View {
        // ✨ 核心重构：移除外层 ZStack 与固定背景，使 ScrollView 成为绝对主角，透出全局统一底层背景
        ScrollView(.vertical, showsIndicators: false) {
            ZStack {
                VStack(spacing: 0) {
                    if yearlySnapshot.books.isEmpty {
                        EmptyStateView(
                            systemImage: "calendar.badge.exclamationmark",
                            title: "暂无 \(String(selectedYear)) 年轨迹",
                            message: selectedYear == Calendar.current.component(.year, from: Date()) ? "今年还没有读完的书籍，继续努力哦！" : "这一年没有留下已读记录。",
                            minHeight: 400
                        )
                        .padding(.top, 140)
                    } else {
                        wallContentView
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 60) // 底部留白
        }
        // ================= ✨ 顶层悬浮高定玻璃 Header (使用 Overlay 挂载) =================
        .overlay(alignment: .top) {
            AppPageHeader(contentID: "\(selectedYear)-\(yearlySnapshot.books.count)-\(yearlySnapshot.totalDaysRead)") {
                AppHeaderTitle("\(String(selectedYear)) 年度轨迹", subtitle: "以年份回看阅读留下的路径。")
            } trailingContent: { PageStatsCompact(items: yearlyHeaderStats) }
        }
        .onAppear {
            availableYears = yearlySnapshot.availableYears
        }
        .onChange(of: selectedYear) { oldYear, newYear in
            previousYear = oldYear
        }
        .onChange(of: yearlySnapshot.availableYears) { _, newYears in
            availableYears = newYears
        }
    }
    
    // MARK: - ✨ 子视图分层
    
    @ViewBuilder
    private var wallContentView: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .blue.opacity(0.5), location: 0.1),
                            .init(color: .blue.opacity(0.1), location: 0.9),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 2)
                
            LazyVStack(spacing: 80) {
                ForEach(Array(yearlySnapshot.books.enumerated()), id: \.element.id) { index, book in
                    TimelineRowView(
                        book: book,
                        isLeft: index % 2 == 0,
                        selectedBook: $selectedBook
                    )
                    .transition(.appCardGlide)
                    .zIndex(selectedBook?.id == book.id ? 999 : 0)
                }
            }
            .padding(.vertical, 40)
        }
        .padding(.top, 160)
        .id(selectedYear)
        .transition(.opacity)
    }

    private var yearlyHeaderStats: [PageStatItemData] {
        [
            PageStatItemData(title: "完结作品", value: "\(yearlySnapshot.books.count)", color: .indigo),
            PageStatItemData(title: "打卡天数", value: "\(yearlySnapshot.totalDaysRead)", color: AppColors.readingAmber),
            PageStatItemData(title: "阅读时长", value: "\(yearlySnapshot.totalReadingHours)", color: .teal),
            PageStatItemData(title: "最高连续", value: "\(yearlySnapshot.longestStreak)", color: .pink),
        ]
    }
    
}

// MARK: - ✨ 子组件：时间轴行容器

private struct TimelineRowView: View {
    let book: Book
    let isLeft: Bool
    @Binding var selectedBook: Book?
    @State private var isHovered = false
    
    private var dateStr: String {
        guard let date = book.finishDate else { return "未知" }
        return AppFormatters.chineseShortDateFormatter.string(from: date)
    }
    
    // ✨ 直接从 AppConstants 提取颜色，如果评分为 0 (nil)，则默认回退为 .blue
    private var recColor: Color {
        AppConstants.recommendationData(for: book.rating)?.color ?? .blue
    }
    
    var body: some View {
        let safeRating = book.rating
        
        HStack(spacing: 0) {
            // 左侧内容区
            Group {
                if isLeft {
                    TimelineCardView(book: book, isLeft: true, isHovered: $isHovered, selectedBook: $selectedBook, recColor: recColor)
                        .padding(.trailing, 60)
                } else {
                    TimelineDateView(dateStr: dateStr, rating: safeRating, isLeft: true, isHovered: isHovered, recColor: recColor)
                        .padding(.trailing, 60)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            
            // 中轴线圆点节点
            ZStack {
                Circle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(width: 14, height: 14)
                
                Circle()
                    .stroke(isHovered ? recColor : Color.blue.opacity(0.4), lineWidth: 3)
                
                if isHovered {
                    Circle()
                        .fill(recColor)
                        .frame(width: 6, height: 6)
                        .transition(.scale)
                }
            }
            .frame(width: 20)
            .zIndex(10)
            .scaleEffect(isHovered ? 1.08 : 1.0)
            .animation(.appControlFeedback, value: isHovered)
            
            // 右侧内容区
            Group {
                if isLeft {
                    TimelineDateView(dateStr: dateStr, rating: safeRating, isLeft: false, isHovered: isHovered, recColor: recColor)
                        .padding(.leading, 60)
                } else {
                    TimelineCardView(book: book, isLeft: false, isHovered: $isHovered, selectedBook: $selectedBook, recColor: recColor)
                        .padding(.leading, 60)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TimelineDateView: View {
    let dateStr: String
    let rating: Int
    let isLeft: Bool
    let isHovered: Bool
    let recColor: Color
    
    var body: some View {
        VStack(alignment: isLeft ? .trailing : .leading, spacing: 8) {
            Text(dateStr)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(isHovered ? recColor : .primary)
                .opacity(isHovered ? 1.0 : 0.8)
            
            // ✨ 核心清理：直接调用全局引擎解包
            if let data = AppConstants.recommendationData(for: rating) {
                HStack(spacing: 4) {
                    Image(systemName: data.icon)
                    Text(data.text)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(data.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .glassEffect(.clear.tint(data.color.opacity(0.2)), in: .capsule)
            }
        }
        .offset(y: isHovered ? -2 : 0)
        .animation(.appSnappy, value: isHovered)
    }
}
// MARK: - ✨ 子组件：多彩单本卡片 (镜像对齐版)

private struct TimelineCardView: View {
    let book: Book
    let isLeft: Bool
    @Binding var isHovered: Bool
    @Binding var selectedBook: Book?
    let recColor: Color
    
    var body: some View {
        HStack(spacing: 24) {
            // ✨ 完全对称结构排版
            if isLeft {
                textSection
                coverSection
            } else {
                coverSection
                textSection
            }
        }
        .padding(24)
        .frame(width: 420, alignment: isLeft ? .trailing : .leading)
        .background(
            Color(nsColor: .controlBackgroundColor)
                .opacity(isHovered ? 0.9 : 0.6)
                .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(isHovered ? 0.15 : 0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.02), radius: isHovered ? 10 : 4, y: isHovered ? 3 : 2)
        .contentShape(Rectangle())
        .onHover { h in
            withAnimation(.appControlFeedback) { isHovered = h }
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .onChange(of: selectedBook) { _, newValue in
            if newValue != nil { isHovered = false }
        }
        .onTapGesture {
            selectedBook = book
        }
    }
    
    private var coverSection: some View {
        let safeTitle = book.title
        return BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: safeTitle)
            .frame(width: 100, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 6, y: 3)
            .scaleEffect(isHovered ? 1.012 : 1.0)
    }
    
    private var textSection: some View {
        let safeTitle = book.title
        let safeAuthor = book.author
        let notesCount = (book.excerpts?.count ?? 0)
        
        return VStack(alignment: isLeft ? .trailing : .leading, spacing: 12) {
            VStack(alignment: isLeft ? .trailing : .leading, spacing: 4) {
                Text(safeTitle)
                    .font(.system(size: 16, weight: .bold))
                    // ✨ 悬浮时，书名亮起推荐色
                    .foregroundColor(isHovered ? recColor : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(isLeft ? .trailing : .leading)
                
                HStack(alignment: .center, spacing: 8) {
                    if isLeft {
                        if notesCount > 0 { notesBadge(count: notesCount) }
                        Text(safeAuthor)
                            .font(.system(size: 13, weight: .medium))
                            // ✨ 悬浮时，作者亮起推荐色
                            .foregroundColor(isHovered ? recColor : .secondary)
                            .lineLimit(1)
                    } else {
                        Text(safeAuthor)
                            .font(.system(size: 13, weight: .medium))
                            // ✨ 悬浮时，作者亮起推荐色
                            .foregroundColor(isHovered ? recColor : .secondary)
                            .lineLimit(1)
                        if notesCount > 0 { notesBadge(count: notesCount) }
                    }
                }
            }
            
            ratingView
            tagView
            
            Spacer(minLength: 4)
            TimelineJourneyTicket(book: book, isLeft: isLeft)
        }
        .frame(maxWidth: .infinity, alignment: isLeft ? .trailing : .leading)
    }
    
    private func notesBadge(count: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "pencil.and.outline")
                .font(.system(size: 9))
            Text("\(count)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.orange.opacity(0.1))
        .clipShape(Capsule())
    }
    
    @ViewBuilder private var ratingView: some View {
        let safeRating = book.rating
        if safeRating > 0 {
            HStack(spacing: 4) {
                if isLeft {
                    if safeRating >= 5 {
                        Image(systemName: "crown.fill").font(.system(size: 10)).foregroundColor(.orange)
                    }
                    Text(safeRating < AppConstants.ratingPoeticTexts.count ? AppConstants.ratingPoeticTexts[safeRating] : "")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.orange).padding(.trailing, 4)
                    HStack(spacing: 2) {
                        ForEach(1 ... 7, id: \.self) { i in
                            Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(i <= safeRating ? .yellow : Color.secondary.opacity(0.2))
                        }
                    }
                } else {
                    HStack(spacing: 2) {
                        ForEach(1 ... 7, id: \.self) { i in
                            Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(i <= safeRating ? .yellow : Color.secondary.opacity(0.2))
                        }
                    }
                    Text(safeRating < AppConstants.ratingPoeticTexts.count ? AppConstants.ratingPoeticTexts[safeRating] : "")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.orange).padding(.leading, 4)
                    if safeRating >= 5 {
                        Image(systemName: "crown.fill").font(.system(size: 10)).foregroundColor(.orange)
                    }
                }
            }
        }
    }
    
    @ViewBuilder private var tagView: some View {
        let safeTags = book.tags
        if !safeTags.isEmpty {
            HStack(spacing: 6) {
                let displayTags = isLeft ? Array(safeTags.prefix(3).reversed()) : Array(safeTags.prefix(3))
                ForEach(displayTags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.indigo)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.indigo.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}

// MARK: - ✨ 子组件：时间轴历时胶囊 (完全降噪版)

private struct TimelineJourneyTicket: View {
    let book: Book
    let isLeft: Bool
    
    var body: some View {
        let days = calculateDays(start: book.startDate, end: book.finishDate)
        
        let startView = VStack(alignment: .center, spacing: 2) {
            Text("始于")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary.opacity(0.6))
            Text(formatShortDate(book.startDate))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
        }.frame(width: 40)
        
        let endView = VStack(alignment: .center, spacing: 2) {
            Text("终于")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary.opacity(0.6))
            Text(formatShortDate(book.finishDate))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
        }.frame(width: 40)
        
        let midView = VStack(spacing: 4) {
            HStack(spacing: 2) {
                if isLeft {
                    Image(systemName: "chevron.left").font(.system(size: 8, weight: .bold)).foregroundColor(.teal)
                    Rectangle().fill(Color.teal.opacity(0.4)).frame(height: 1)
                    Circle().fill(Color.teal).frame(width: 4, height: 4)
                } else {
                    Circle().fill(Color.teal).frame(width: 4, height: 4)
                    Rectangle().fill(Color.teal.opacity(0.4)).frame(height: 1)
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundColor(.teal)
                }
            }
            
            // ✨ 严格要求：完全移除 Hover 背景填充效果，只保留原始青色
            Text("历时 \(days) 天")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.teal)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.teal.opacity(0.15))
                .clipShape(Capsule())
            
        }.padding(.horizontal, 8)
        
        HStack(spacing: 0) {
            if isLeft {
                endView
                midView
                startView
            } else {
                startView
                midView
                endView
            }
        }
    }
    
    private func formatShortDate(_ date: Date?) -> String {
        guard let d = date else { return "未知" }
        return AppFormatters.dotShortDateFormatter.string(from: d)
    }
    
    private func calculateDays(start: Date?, end: Date?) -> Int {
        guard let s = start, let e = end else { return 1 }
        let calendar = Calendar.current
        let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: s), to: calendar.startOfDay(for: e)).day ?? 0
        return max(1, diff + 1)
    }
}

#endif
