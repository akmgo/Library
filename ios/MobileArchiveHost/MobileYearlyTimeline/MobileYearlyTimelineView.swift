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

    // ✨ 动画与生命周期引擎
    @State private var isEntranceAnimated: Bool = false
    @State private var hasAppeared: Bool = false // 核心修复：防止从详情页退回时重复触发入场动画
    @State private var previousYear: Int = Calendar.current.component(.year, from: Date())

    private var yearlySnapshot: ReadingStatsCalculator.YearlyArchiveSnapshot {
        ReadingStatsCalculator.yearlyArchiveSnapshot(
            books: books,
            sessions: sessions,
            selectedYear: selectedYear
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppColors.primaryBackground(for: colorScheme).ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        MobileYearlyStatsHeader(
                            year: selectedYear,
                            booksCount: yearlySnapshot.books.count,
                            daysCount: yearlySnapshot.totalDaysRead,
                            hoursCount: yearlySnapshot.totalReadingHours,
                            streakCount: yearlySnapshot.longestStreak
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                        
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
                    .padding(.bottom, 120)
                    .opacity(isEntranceAnimated ? 1.0 : 0.0)
                    .offset(y: isEntranceAnimated ? 0 : 40)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isEntranceAnimated)
                }
            }
            .navigationTitle("\(String(selectedYear)) 年轨迹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    MobileYearSelectorMenu(selectedYear: $selectedYear, availableYears: yearlySnapshot.availableYears)
                }
            }
            .onAppear {
                // ✨ 核心修复：锁定生命周期，只在首次进入时触发下拉动画
                if !hasAppeared {
                    hasAppeared = true
                    isEntranceAnimated = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isEntranceAnimated = true
                        }
                    }
                }
            }
            .onChange(of: selectedYear) { oldYear, newYear in
                previousYear = oldYear
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
// MARK: - 📊 2. 顶部数据面板组件
// ============================================================================

struct MobileYearlyStatsHeader: View {
    let year: Int; let booksCount: Int; let daysCount: Int; let hoursCount: Int; let streakCount: Int
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            MobileStatItem(title: "完结作品", value: "\(booksCount)", unit: "部", color: .indigo)
            Divider().frame(height: 32).opacity(0.5)
            MobileStatItem(title: "打卡天数", value: "\(daysCount)", unit: "天", color: .orange)
            Divider().frame(height: 32).opacity(0.5)
            MobileStatItem(title: "阅读时长", value: "\(hoursCount)", unit: "时", color: .teal)
            Divider().frame(height: 32).opacity(0.5)
            MobileStatItem(title: "最高连续", value: "\(streakCount)", unit: "天", color: .pink)
        }
        .padding(.vertical, 16)
        .background(
            AppColors.secondaryBackground(for: colorScheme).opacity(0.8)
                .background(AppMaterials.card)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }
}

private struct MobileStatItem: View {
    let title: String; let value: String; let unit: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(color)
                    .contentTransition(.numericText(value: Double(value) ?? 0))
                Text(unit)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
            Text(title).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MobileYearSelectorMenu: View {
    @Binding var selectedYear: Int
    let availableYears: [Int]
    
    var body: some View {
        Menu {
            ForEach(availableYears, id: \.self) { year in
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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

// ============================================================================
// MARK: - 📍 3. 单轨时间轴行组件
// ============================================================================

struct MobileTimelineRowView: View {
    let book: Book
    let isLast: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(AppColors.primaryBackground(for: colorScheme)).frame(width: 14, height: 14)
                    Circle().stroke(Color.blue.opacity(0.6), lineWidth: 3)
                }.frame(height: 28)
                
                Rectangle()
                    .fill(isLast ? LinearGradient(colors: [Color.blue.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [Color.blue.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 2)
            }
            .padding(.leading, 20)
            
            VStack(alignment: .leading, spacing: 12) {
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
        HStack(alignment: .center, spacing: 12) {
            Text(dateStr)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(.secondary)
            
            if let data = AppConstants.recommendationData(for: book.rating) {
                HStack(spacing: 4) {
                    Image(systemName: data.icon).font(.system(size: 11))
                    Text(data.text).font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(data.color)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(data.color.opacity(0.15))
                .clipShape(Capsule())
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
        ZStack(alignment: .leading) {
            // 背景水印
            GeometryReader { geo in
                ZStack {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(Color.blue.opacity(0.03))
                        .position(x: geo.size.width - 20, y: 20)
                }
            }.clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            
            HStack(alignment: .top, spacing: 16) {
                BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                    .frame(width: 80, height: 120).clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.bookCover).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                    .shadow(color: Color.black.opacity(0.1), radius: 6, y: 3)
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(book.title).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary).lineLimit(1).layoutPriority(1)
                        Spacer(minLength: 12)
                        Text(book.author).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary).lineLimit(1).fixedSize(horizontal: true, vertical: false).layoutPriority(0)
                    }.frame(maxWidth: .infinity)
                    
                    Spacer()
                    
                    if book.rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(1 ... 7, id: \.self) { i in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(i <= book.rating ? .yellow : Color.secondary.opacity(0.2))
                            }
                            if book.rating < AppConstants.ratingPoeticTexts.count {
                                Text(AppConstants.ratingPoeticTexts[book.rating])
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.orange)
                                    .padding(.leading, 4)
                            }
                        }
                    } else { Color.clear.frame(height: 12) }
                    
                    Spacer()
                    
                    if !book.tags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(Array(book.tags.prefix(3)), id: \.self) { tag in
                                Text(tag).font(.system(size: 9, weight: .bold)).foregroundColor(.indigo)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(Color.indigo.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))
                            }
                        }
                    } else { Color.clear.frame(height: 15) }
                    
                    Spacer()
                    MobileJourneyTicket(book: book)
                }
                .frame(height: 120)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .background(
            AppColors.secondaryBackground(for: colorScheme)
                .opacity(0.9)
                .background(AppMaterials.card)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }
}

struct MobileJourneyTicket: View {
    let book: Book
    var body: some View {
        let days = calculateDays(start: book.startDate, end: book.finishDate)
        
        HStack(spacing: 0) {
            Text(formatShortDate(book.startDate)).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.secondary)
            HStack(spacing: 4) {
                Circle().fill(Color.teal).frame(width: 4, height: 4)
                Rectangle().fill(Color.teal.opacity(0.5)).frame(height: 1)
                
                Text("\(days)天").font(.system(size: 9, weight: .bold)).foregroundColor(.teal).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(Color.teal.opacity(0.15)).clipShape(Capsule())
                
                Rectangle().fill(Color.teal.opacity(0.5)).frame(height: 1)
                Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundColor(.teal)
            }.padding(.horizontal, 8)
            Text(formatShortDate(book.finishDate)).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func formatShortDate(_ date: Date?) -> String {
        guard let d = date else { return "未知" }; let formatter = DateFormatter(); formatter.dateFormat = "M.d"; return formatter.string(from: d)
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
#endif
