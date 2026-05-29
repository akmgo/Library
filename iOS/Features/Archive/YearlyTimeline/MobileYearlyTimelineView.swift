#if os(iOS)
import SwiftData
import SwiftUI

// ============================================================================
// MARK: - 📱 1. 年度阅读轨迹 (主视图)
// ============================================================================

struct MobileYearlyTimelineView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @Query(sort: \ReadingSession.date, order: .reverse) private var sessions: [ReadingSession]
    
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    private var yearlySnapshot: ReadingStatsCalculator.YearlyArchiveSnapshot {
        ReadingStatsCalculator.yearlyArchiveSnapshot(
            books: books,
            sessions: sessions,
            selectedYear: selectedYear
        )
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            AppColors.primaryBackground(for: colorScheme).ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        MobilePageStatsHeader(items: [
                            PageStatItemData(title: "完结作品", value: "\(yearlySnapshot.books.count)", color: .indigo),
                            PageStatItemData(title: "打卡天数", value: "\(yearlySnapshot.totalDaysRead)", color: AppColors.readingAmber),
                            PageStatItemData(title: "阅读时长", value: "\(yearlySnapshot.totalReadingHours)", color: .teal),
                            PageStatItemData(title: "最高连续", value: "\(yearlySnapshot.longestStreak)", color: .pink),
                        ], bottomPadding: 24)
                        
                        if yearlySnapshot.books.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(yearlySnapshot.books.enumerated()), id: \.element.id) { index, book in
                                    MobileTimelineRowView(
                                        book: book,
                                        isLast: index == yearlySnapshot.books.count - 1
                                    )
                                }
                            }
                        }
                    }
                    .padding(.bottom, AppSpacing.emptyState)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(yearlySnapshot.availableYears, id: \.self) { year in
                            Button(action: { selectedYear = year }) {
                                HStack {
                                    Text(String(year))
                                    if year == selectedYear { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        Text(String(selectedYear))
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
        }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "calendar.badge.exclamationmark",
            title: "暂无 \(String(selectedYear)) 年轨迹",
            message: selectedYear == Calendar.current.component(.year, from: Date()) ? "今年还没有读完的书籍，继续努力哦！" : "这一年没有留下已读记录。",
            iconSize: 56,
            minHeight: 320
        )
        .padding(.top, 24)
    }
    
}

// ============================================================================
// MARK: - 📍 3. 单轨时间轴行组件
// ============================================================================

struct MobileTimelineRowView: View {
    let book: Book
    let isLast: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.m) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(AppColors.primaryBackground(for: colorScheme)).frame(width: 14, height: 14)
                    Circle().stroke(Color.blue.opacity(0.6), lineWidth: 3)
                }.frame(height: 28)
                
                Rectangle()
                    .fill(isLast ? LinearGradient(colors: [Color.secondary.opacity(0.14), .clear], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [Color.secondary.opacity(0.14)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 2)
            }
            .padding(.leading, 20)
            
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                MobileTimelineDateBadgeView(book: book)
                
                // ✨ 核心修复：彻底摒弃自定义交互样式，回归最原生、最敏捷的点击反馈
                NavigationLink(destination: MobileBookDetailView(book: book)) {
                    MobileTimelineCardView(book: book)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 40)
            .padding(.trailing, 20)
        }
    }
}

private struct MobileTimelineDateBadgeView: View {
    let book: Book
    
    private var dateStr: String {
        guard let date = book.finishDate else { return "未知" }
        let formatter = DateFormatter(); formatter.dateFormat = "M月d日"; return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.s) {
            Text(dateStr)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(.secondary)
            
            if let data = AppConstants.recommendationData(for: book.rating) {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: data.icon).font(.system(size: 11))
                    Text(data.text).font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(data.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .appCapsuleStyle(tint: data.color)
            }
        }
    }
}

// ============================================================================
// MARK: - 🏷️ 4. 核心多彩卡片与历时胶囊
// ============================================================================

struct MobileTimelineCardView: View {
    let book: Book
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        AppCard {
            YearlyTimelineBookCardContent(book: book, coverWidth: 100)
        }
    }
}

#if DEBUG
#Preview("年度时间线") {
    PreviewWithData {
        MobileYearlyTimelineView()
    }
}
#endif


#endif
