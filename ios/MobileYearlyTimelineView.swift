#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 📱 年度阅读轨迹 (iOS 沉浸数据版)
struct MobileYearlyTimelineView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Query var books: [Book]
    @Query var records: [ReadingRecord] // 引入打卡记录计算宏观数据
    
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
private struct MobileYearlyStatsHeader: View {
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

// MARK: - 📱 横竖屏双引擎时间轴组件
private struct MobileTimelineRowView: View {
    let book: Book; let index: Int; let isLast: Bool
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        let isLandscape = verticalSizeClass == .compact
        let isLeft = index % 2 == 0
        
        if isLandscape {
            // ================= 横屏：左右交错对齐 =================
            HStack(spacing: 0) {
                Group {
                    if isLeft {
                        NavigationLink(destination: MobileBookDetailView(book: book)) { MobileTimelineCardView(book: book) }.buttonStyle(.plain).padding(.trailing, 20)
                    } else {
                        MobileTimelineDateView(book: book, isLeft: true).padding(.trailing, 20)
                    }
                }.frame(maxWidth: .infinity, alignment: .trailing)
                
                // 中心轴线
                VStack(spacing: 0) {
                    ZStack {
                        Circle().fill(Color(uiColor: .systemGroupedBackground)).frame(width: 14, height: 14)
                        Circle().stroke(Color.blue.opacity(0.6), lineWidth: 3)
                    }.frame(height: 28)
                    Rectangle().fill(isLast ? LinearGradient(colors: [Color.blue.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [Color.blue.opacity(0.3)], startPoint: .top, endPoint: .bottom)).frame(width: 2)
                }
                
                Group {
                    if isLeft {
                        MobileTimelineDateView(book: book, isLeft: false).padding(.leading, 20)
                    } else {
                        NavigationLink(destination: MobileBookDetailView(book: book)) { MobileTimelineCardView(book: book) }.buttonStyle(.plain).padding(.leading, 20)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 40).padding(.bottom, 40)
            
        } else {
            // ================= 竖屏：经典的居左时间轴 =================
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle().fill(Color(uiColor: .systemGroupedBackground)).frame(width: 14, height: 14)
                        Circle().stroke(Color.blue.opacity(0.6), lineWidth: 3)
                    }.frame(height: 28)
                    Rectangle().fill(isLast ? LinearGradient(colors: [Color.blue.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [Color.blue.opacity(0.3)], startPoint: .top, endPoint: .bottom)).frame(width: 2)
                }
                .padding(.leading, 20)
                
                VStack(alignment: .leading, spacing: 12) {
                    MobileTimelineDateView(book: book, isLeft: false)
                    NavigationLink(destination: MobileBookDetailView(book: book)) {
                        MobileTimelineCardView(book: book)
                    }.buttonStyle(PlainButtonStyle())
                }
                .padding(.bottom, 40).padding(.trailing, 20)
            }
        }
    }
}

private struct MobileTimelineDateView: View {
    let book: Book; let isLeft: Bool
    private var dateStr: String { guard let date = book.endTime else { return "未知" }; let formatter = DateFormatter(); formatter.dateFormat = "M月d日"; return formatter.string(from: date) }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if isLeft { Spacer() }
            Text(dateStr).font(.system(size: 20, weight: .bold, design: .rounded)).tracking(1).foregroundColor(.secondary)
            if (book.rating ?? 0) >= 4 {
                // ✨ 橙色火焰强推徽章
                HStack(spacing: 4) { Image(systemName: "flame.fill").font(.system(size: 11)); Text("强推").font(.system(size: 11, weight: .bold)) }.foregroundColor(.orange).padding(.horizontal, 10).padding(.vertical, 4).background(Color.orange.opacity(0.15)).clipShape(Capsule())
            }
            if !isLeft { Spacer() }
        }
    }
}

// MARK: - 📱 子组件：原生时间轴多彩卡片
private struct MobileTimelineCardView: View {
    let book: Book
    let ratingTexts = ["", "一星毒草", "二星平庸", "三星粮草", "四星推荐", "改变人生"]
    
    var body: some View {
        let safeTitle = book.title ?? "未知书名"
        let safeAuthor = book.author ?? "未知作者"
        let safeRating = book.rating ?? 0
        let safeTags = book.tags ?? []
        
        ZStack(alignment: .leading) {
            GeometryReader { geo in
                ZStack { Image(systemName: "quote.opening").font(.system(size: 80, weight: .bold)).foregroundColor(Color.blue.opacity(0.03)).position(x: geo.size.width - 20, y: 20) }
            }.clipShape(RoundedRectangle(cornerRadius: 16))
            
            HStack(alignment: .top, spacing: 16) {
                LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                    .frame(width: 80, height: 120).clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                    .shadow(color: Color.black.opacity(0.1), radius: 6, y: 3)
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(safeTitle).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary).lineLimit(1).layoutPriority(1)
                        Spacer(minLength: 12)
                        Text(safeAuthor).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary).lineLimit(1).fixedSize(horizontal: true, vertical: false).layoutPriority(0)
                    }.frame(maxWidth: .infinity)
                    
                    Spacer()
                    
                    if safeRating > 0 {
                        HStack(spacing: 2) {
                            // ✨ 金色星星
                            ForEach(1 ... 5, id: \.self) { i in Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(i <= safeRating ? .yellow : Color.secondary.opacity(0.2)) }
                            Text(safeRating < ratingTexts.count ? ratingTexts[safeRating] : "").font(.system(size: 10, weight: .bold)).foregroundColor(.orange).padding(.leading, 4)
                            if safeRating == 5 { Image(systemName: "crown.fill").font(.system(size: 10)).foregroundColor(.orange) }
                        }
                    } else { Color.clear.frame(height: 12) }
                    
                    Spacer()
                    
                    if !safeTags.isEmpty {
                        HStack(spacing: 6) {
                            // ✨ 靛蓝色标签
                            ForEach(Array(safeTags.prefix(3)), id: \.self) { tag in
                                Text(tag).font(.system(size: 9, weight: .bold)).foregroundColor(.indigo)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(Color.indigo.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    } else { Color.clear.frame(height: 15) }
                    
                    Spacer()
                    MobileJourneyTicket(book: book)
                }
                .frame(height: 120)
            }.padding(16)
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }
}

// ✨ 移动专属：超微缩青色护照通行证
private struct MobileJourneyTicket: View {
    let book: Book
    var body: some View {
        let days = calculateDays(start: book.startTime, end: book.endTime)
        
        HStack(spacing: 0) {
            Text(formatShortDate(book.startTime)).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.secondary)
            HStack(spacing: 4) {
                Circle().fill(Color.teal).frame(width: 4, height: 4)
                Rectangle().fill(Color.teal.opacity(0.5)).frame(height: 1)
                
                Text("\(days)天").font(.system(size: 9, weight: .bold)).foregroundColor(.teal).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(Color.teal.opacity(0.15)).clipShape(Capsule())
                
                Rectangle().fill(Color.teal.opacity(0.5)).frame(height: 1)
                Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundColor(.teal)
            }.padding(.horizontal, 8)
            Text(formatShortDate(book.endTime)).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.secondary)
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
