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
    @State private var yearlySnapshot: ReadingStatsCalculator.YearlyArchiveSnapshot?
    @State private var yearlyHeaderStats: [PageStatItemData] = []

    private var yearlyFP: String { "\(books.count)-\(sessions.count)-\(selectedYear)" }

    var body: some View {
        // ✨ 核心重构：移除外层 ZStack 与固定背景，使 ScrollView 成为绝对主角，透出全局统一底层背景
        ScrollView(.vertical, showsIndicators: false) {
            ZStack {
                LazyVStack(spacing: 0) {
                    if let snapshot = yearlySnapshot, !snapshot.books.isEmpty {
                        wallContentView
                    } else if yearlySnapshot != nil {
                        EmptyStateView(
                            systemImage: "calendar.badge.exclamationmark",
                            title: "暂无 \(String(selectedYear)) 年轨迹",
                            message: selectedYear == Calendar.current.component(.year, from: Date()) ? "今年还没有读完的书籍，继续努力哦！" : "这一年没有留下已读记录。",
                            minHeight: 400
                        )
                        .padding(.top, 140)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 60) // 底部留白
        }
        // ================= ✨ 顶层悬浮高定玻璃 Header (使用 Overlay 挂载) =================
        .overlay(alignment: .top) {
            AppPageHeader(contentID: "\(selectedYear)-\(yearlySnapshot?.books.count ?? 0)-\(yearlySnapshot?.totalDaysRead ?? 0)") {
                AppHeaderTitle("\(String(selectedYear)) 年度轨迹", subtitle: "以年份回看阅读留下的路径。")
            } trailingContent: { PageStatsCompact(items: yearlyHeaderStats) }
        }
        .onAppear { refreshYearlyData() }
        .onChange(of: yearlyFP) { _, _ in refreshYearlyData() }
        .onChange(of: selectedYear) { oldYear, newYear in
            previousYear = oldYear
        }
    }
    
    // MARK: - ✨ 子视图分层
    
    @ViewBuilder
    private var wallContentView: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.secondary.opacity(0.14))
                .frame(width: 2)
                
            LazyVStack(spacing: 80) {
                ForEach(Array((yearlySnapshot?.books ?? []).enumerated()), id: \.element.id) { index, book in
                    TimelineRowView(
                        book: book,
                        isLeft: index % 2 == 0,
                        selectedBook: $selectedBook
                    )
                    .zIndex(selectedBook?.id == book.id ? 999 : 0)
                }
            }
            .padding(.vertical, 40)
        }
        .padding(.top, 160)
        .id(selectedYear)
        .transition(.opacity)
    }

    private func refreshYearlyData() {
        let snapshot = ReadingStatsCalculator.yearlyArchiveSnapshot(
            books: books, sessions: sessions, selectedYear: selectedYear
        )
        yearlySnapshot = snapshot
        availableYears = snapshot.availableYears
        yearlyHeaderStats = [
            PageStatItemData(title: "完结作品", value: "\(snapshot.books.count)", color: .indigo),
            PageStatItemData(title: "打卡天数", value: "\(snapshot.totalDaysRead)", color: AppColors.readingAmber),
            PageStatItemData(title: "阅读时长", value: "\(snapshot.totalReadingHours)", color: .teal),
            PageStatItemData(title: "最高连续", value: "\(snapshot.longestStreak)", color: .pink),
        ]
    }
}

// MARK: - ✨ 子组件：时间轴行容器

private struct TimelineRowView: View {
    let book: Book
    let isLeft: Bool
    @Binding var selectedBook: Book?
    @Environment(\.colorScheme) private var colorScheme

    private var dateStr: String {
        guard let date = book.finishDate else { return "未知" }
        return AppFormatters.chineseShortDateFormatter.string(from: date)
    }

    var body: some View {
        let safeRating = book.rating

        HStack(spacing: 0) {
            Group {
                if isLeft {
                    TimelineCardView(book: book, isLeft: true, selectedBook: $selectedBook)
                        .padding(.trailing, 60)
                } else {
                    TimelineDateView(dateStr: dateStr, rating: safeRating, isLeft: true)
                        .padding(.trailing, 60)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            ZStack {
                Circle()
                    .fill(AppColors.primaryBackground(for: colorScheme))
                    .frame(width: 14, height: 14)
                Circle()
                    .stroke(Color.blue.opacity(0.4), lineWidth: 3)
            }
            .frame(width: 20)
            .zIndex(10)

            Group {
                if isLeft {
                    TimelineDateView(dateStr: dateStr, rating: safeRating, isLeft: false)
                        .padding(.leading, 60)
                } else {
                    TimelineCardView(book: book, isLeft: false, selectedBook: $selectedBook)
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

    var body: some View {
        VStack(alignment: isLeft ? .trailing : .leading, spacing: 8) {
            Text(dateStr)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(.primary)
                .opacity(0.8)

            if let data = AppConstants.recommendationData(for: rating) {
                HStack(spacing: 4) {
                    Image(systemName: data.icon)
                    Text(data.text)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(data.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .appCapsuleStyle(tint: data.color)
            }
        }
    }
}
// MARK: - ✨ 子组件：多彩单本卡片 (镜像对齐版)

private struct TimelineCardView: View {
    let book: Book
    let isLeft: Bool
    @Binding var selectedBook: Book?

    var body: some View {
        AppCard {
            YearlyTimelineBookCardContent(book: book, isMirrored: isLeft)
        }
        .frame(width: 420, alignment: isLeft ? .trailing : .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedBook = book
        }
    }
}

#endif
