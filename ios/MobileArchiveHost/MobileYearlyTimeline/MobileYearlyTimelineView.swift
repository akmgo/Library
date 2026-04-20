#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 📱 年度阅读轨迹 (iOS 沉浸数据版)

/// 展现当年全部已读书籍的“时间长河”视图。
///
/// **响应式排版特性：**
/// 该视图内部对 `isLandscape` (横屏状态) 做了极致的适配：
/// - 竖屏状态下，保持居左的时间线与偏右的卡片。
/// - 横屏状态下，自动切换为居中蛇形排版，左右两侧卡片交错摆放，完美利用大屏幕的宽度。
struct MobileYearlyTimelineView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Query var books: [Book]
    @Query var records: [ReadingRecord]
    
    var isLandscape: Bool { verticalSizeClass == .compact }
    
    // 状态管理
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var availableYears: [Int] = [Calendar.current.component(.year, from: Date())]
    @State private var cachedYearlyBooks: [Book] = []
    
    // 宏观数据
    @State private var totalDaysReadThisYear: Int = 0
    @State private var totalReadingHoursThisYear: Int = 0
    @State private var longestStreakThisYear: Int = 0
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // 1. 系统底色
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                // 2. 顶部氛围光
                Circle()
                    .fill(Color.indigo.opacity(0.12))
                    .blur(radius: 80)
                    .frame(width: 300, height: 300)
                    .offset(x: isLandscape ? -200 : -100, y: -150)
                    .ignoresSafeArea()
                
                // 3. 滚动视图
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // ✨ 顶部数据看板
                        MobileYearlyStatsHeader(
                            year: selectedYear,
                            booksCount: cachedYearlyBooks.count,
                            daysCount: totalDaysReadThisYear,
                            hoursCount: totalReadingHoursThisYear,
                            streakCount: longestStreakThisYear
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                        
                        if cachedYearlyBooks.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(cachedYearlyBooks.enumerated()), id: \.element.id) { index, book in
                                    MobileTimelineRowView(
                                        book: book,
                                        index: index,
                                        isLast: index == cachedYearlyBooks.count - 1
                                    )
                                }
                            }
                        }
                    }
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("\(String(selectedYear)) 年轨迹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(availableYears, id: \.self) { year in
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                selectedYear = year
                            }) {
                                HStack { Text("\(String(year)) 年"); if selectedYear == year { Image(systemName: "checkmark") } }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text("切换")
                        }
                        .font(.system(size: 16, weight: .bold))
                    }
                }
            }
            .onAppear { updateYearlyData() }
            .onChange(of: books) { _, _ in updateYearlyData() }
            .onChange(of: selectedYear) { _, _ in updateYearlyData() }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundColor(Color.gray.opacity(0.4))
            Text(selectedYear == Calendar.current.component(.year, from: Date()) ? "今年还没有读完的书籍，继续努力哦！" : "这一年没有留下已读记录。")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - 算法核心
    
    /// 从全库中提取目标年份的极值打卡数据与对应已读书籍的缓存。
    private func updateYearlyData() {
        let cal = Calendar.current
        
        let years = books.compactMap { book -> Int? in
            guard book.status == .finished, let endDate = book.endTime else { return nil }
            return cal.component(.year, from: endDate)
        }
        var result = Array(Set(years))
        let current = cal.component(.year, from: Date())
        if !result.contains(current) { result.append(current) }
        availableYears = result.sorted(by: >)
        
        cachedYearlyBooks = books.filter { book in
            guard book.status == .finished, let endDate = book.endTime else { return false }
            return cal.component(.year, from: endDate) == selectedYear
        }.sorted { ($0.endTime ?? Date.distantPast) > ($1.endTime ?? Date.distantPast) }
        
        let yearRecords = records.filter { cal.component(.year, from: $0.date ?? Date.distantPast) == selectedYear }
        
        let uniqueDays = Set(yearRecords.compactMap { $0.date.map { cal.startOfDay(for: $0) } }).sorted()
        totalDaysReadThisYear = uniqueDays.count
        
        let totalSeconds = yearRecords.reduce(0) { $0 + $1.readingDuration }
        totalReadingHoursThisYear = Int(totalSeconds / 3600)
        
        var maxStreak = 0; var currentStreak = 0; var previousDate: Date? = nil
        for date in uniqueDays {
            if let prev = previousDate {
                let diff = cal.dateComponents([.day], from: prev, to: date).day ?? 0
                if diff == 1 { currentStreak += 1 } else if diff > 1 { currentStreak = 1 }
            } else { currentStreak = 1 }
            maxStreak = max(maxStreak, currentStreak); previousDate = date
        }
        longestStreakThisYear = maxStreak
    }
}

// MARK: - ✨ iOS 专属：高级玻璃态数据面板

/// 位于顶部，用最简练的空间展示年度四大维度阅读成果。
struct MobileYearlyStatsHeader: View {
    let year: Int; let booksCount: Int; let daysCount: Int; let hoursCount: Int; let streakCount: Int
    
    var body: some View {
        HStack(spacing: 0) {
            MobileStatItem(title: "完结作品", value: "\(booksCount)", unit: "部", color: .indigo)
            Divider().frame(height: 32).opacity(0.5)
            MobileStatItem(title: "打卡天数", value: "\(daysCount)", unit: "天", color: .orange)
            Divider().frame(height: 32).opacity(0.5)
            MobileStatItem(title: "最高连续", value: "\(streakCount)", unit: "天", color: .pink)
        }
        .padding(.vertical, 16)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground).opacity(0.8)
                .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }
}

private struct MobileStatItem: View {
    let title: String; let value: String; let unit: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundColor(color)
                Text(unit).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
            }
            Text(title).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
