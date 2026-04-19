#if os(macOS)
import SwiftData
import SwiftUI
import AppKit

// MARK: - ✨ 年度阅读轨迹 (仪表盘 Header 融合版)
struct YearlyTimelineView: View {
    @Query var books: [Book]
    @Query var records: [ReadingRecord] // 引入记录，用于计算宏观数据
    
    let namespace: Namespace.ID
    @Binding var selectedBook: Book?
    @Binding var activeCoverID: String
    
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var availableYears: [Int] = [Calendar.current.component(.year, from: Date())]
    
    @State private var cachedYearlyBooks: [Book] = []
    
    // ✨ 核心宏观指标
    @State private var totalDaysReadThisYear: Int = 0
    @State private var totalReadingHoursThisYear: Int = 0
    @State private var longestStreakThisYear: Int = 0
    
    var body: some View {
        ZStack(alignment: .top) {
            // ================= 1. 统一氛围感环境背景 =================
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
                                                            
            Circle()
                .fill(Color.indigo.opacity(0.08))
                .blur(radius: 120)
                .frame(width: 800, height: 800)
                .offset(x: -200, y: -300)
            
            // ================= 2. 底层滚动内容区 =================
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if cachedYearlyBooks.isEmpty {
                        ContentUnavailableView {
                            Label("暂无 \(String(selectedYear)) 年轨迹", systemImage: "calendar.badge.exclamationmark")
                        } description: {
                            Text(selectedYear == Calendar.current.component(.year, from: Date()) ? "今年还没有读完的书籍，继续努力哦！" : "这一年没有留下已读记录。")
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                        .padding(.top, 180)
                    } else {
                        // 蛇形时间轴
                        ZStack(alignment: .top) {
                            // 极简流光中轴线
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
                                ForEach(Array(cachedYearlyBooks.enumerated()), id: \.element.id) { index, book in
                                    TimelineRowView(
                                        book: book, isLeft: index % 2 == 0,
                                        namespace: namespace, selectedBook: $selectedBook, activeCoverID: $activeCoverID
                                    )
                                    .zIndex(selectedBook?.id == book.id ? 999 : 0)
                                }
                            }
                            .padding(.vertical, 40)
                        }
                        // 避让顶部悬浮玻璃的高度
                        .padding(.top, 160)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 120)
            }
            
            // ================= 3. ✨ 顶层悬浮高定玻璃 Header =================
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    // 左侧：标题区
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(String(selectedYear)) 年度报告")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("岁月留痕，阅有所获")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 右侧：数据大屏
                    HStack(spacing: 32) {
                        HeaderStatItem(title: "完结作品", value: "\(cachedYearlyBooks.count)", unit: "部", icon: "book.closed.fill", color: .indigo)
                        HeaderStatItem(title: "打卡天数", value: "\(totalDaysReadThisYear)", unit: "天", icon: "calendar", color: .orange)
                        HeaderStatItem(title: "阅读时长", value: "\(totalReadingHoursThisYear)", unit: "小时", icon: "clock.fill", color: .teal)
                        HeaderStatItem(title: "最高连续", value: "\(longestStreakThisYear)", unit: "天", icon: "flame.fill", color: .pink)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 45) // 微调贴顶距离
                .padding(.bottom, 20)
                
                Divider().background(Color.primary.opacity(0.05))
            }
            .background(
                Color.clear
                    .background(.ultraThinMaterial)
                    .opacity(0.85)
            )
            .ignoresSafeArea(edges: .top)
        }
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    ForEach(availableYears, id: \.self) { year in
                        Button(action: { selectedYear = year }) {
                            HStack { Text("\(String(year)) 年"); if selectedYear == year { Image(systemName: "checkmark") } }
                        }
                    }
                } label: {
                    HStack(spacing: 4) { Image(systemName: "calendar"); Text("\(String(selectedYear)) 年") }.foregroundColor(.primary)
                }
                .menuIndicator(.hidden).help("切换回顾年份")
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear { updateYearlyData() }
        .onChange(of: books) { _, _ in updateYearlyData() }
        .onChange(of: selectedYear) { _, _ in updateYearlyData() }
    }
    
    // MARK: - ✨ 算法核心：年度数据提取与极值计算
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

// MARK: - ✨ 玻璃 Header 专属：极致微缩数据块
private struct HeaderStatItem: View {
    let title: String; let value: String; let unit: String; let icon: String; let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.1)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundColor(color.opacity(0.8))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.secondary)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.primary)
                    if !unit.isEmpty { Text(unit).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary.opacity(0.6)) }
                }
            }
        }
    }
}

// MARK: - 时间轴行渲染组件
private struct TimelineRowView: View {
    let book: Book; let isLeft: Bool
    let namespace: Namespace.ID
    @Binding var selectedBook: Book?; @Binding var activeCoverID: String
    @State private var isHovered = false
    
    private var dateStr: String {
        guard let date = book.endTime else { return "未知" }
        let formatter = DateFormatter(); formatter.dateFormat = "M月d日"; return formatter.string(from: date)
    }
    
    var body: some View {
        let safeRating = book.rating ?? 0
        
        HStack(spacing: 0) {
            Group {
                if isLeft { TimelineCardView(book: book, isHovered: $isHovered, namespace: namespace, selectedBook: $selectedBook, activeCoverID: $activeCoverID).padding(.trailing, 60) }
                else { TimelineDateView(dateStr: dateStr, rating: safeRating, isLeft: true, isHovered: isHovered).padding(.trailing, 60) }
            }.frame(maxWidth: .infinity, alignment: .trailing)
            
            // ✨ 中轴节点光晕效果强化
            ZStack {
                Circle().fill(Color(nsColor: .windowBackgroundColor)).frame(width: 14, height: 14)
                Circle().stroke(Color.blue.opacity(isHovered ? 1.0 : 0.4), lineWidth: 3)
                if isHovered { Circle().fill(Color.blue).frame(width: 6, height: 6).transition(.scale) }
            }
            .frame(width: 20).zIndex(10)
            .scaleEffect(isHovered ? 1.3 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
            
            Group {
                if isLeft { TimelineDateView(dateStr: dateStr, rating: safeRating, isLeft: false, isHovered: isHovered).padding(.leading, 60) }
                else { TimelineCardView(book: book, isHovered: $isHovered, namespace: namespace, selectedBook: $selectedBook, activeCoverID: $activeCoverID).padding(.leading, 60) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TimelineDateView: View {
    let dateStr: String; let rating: Int; let isLeft: Bool; let isHovered: Bool
    var body: some View {
        VStack(alignment: isLeft ? .trailing : .leading, spacing: 8) {
            Text(dateStr).font(.system(size: 24, weight: .bold, design: .rounded)).tracking(1)
                .foregroundColor(isHovered ? .blue : .primary).opacity(isHovered ? 1.0 : 0.8)
            // 强推徽章保持金橙色
            if rating >= 4 { HStack(spacing: 4) { Text("🔥 强推").font(.system(size: 11, weight: .bold)) }.foregroundColor(.orange).padding(.horizontal, 10).padding(.vertical, 4).background(Color.orange.opacity(0.1)).clipShape(Capsule()) }
        }
        .offset(y: isHovered ? -2 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
}

// MARK: - ✨ 纯粹干净的多彩单本卡片 (升级色彩体系)
private struct TimelineCardView: View {
    let book: Book; @Binding var isHovered: Bool
    let namespace: Namespace.ID; @Binding var selectedBook: Book?; @Binding var activeCoverID: String
    let ratingTexts = ["", "一星毒草", "二星平庸", "三星粮草", "四星推荐", "经典神作"]
    
    var body: some View {
        HStack(spacing: 24) {
            coverSection
            textSection
        }
        .padding(24)
        .frame(width: 420, alignment: .leading)
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(isHovered ? 0.9 : 0.6)
                .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(isHovered ? 0.15 : 0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(isHovered ? 0.1 : 0.02), radius: isHovered ? 14 : 4, y: isHovered ? 6 : 2)
        .contentShape(Rectangle())
        .onHover { h in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isHovered = h }
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .onChange(of: selectedBook) { _, newValue in if newValue != nil { isHovered = false } }
        .onTapGesture { activeCoverID = "timeline-\(book.id ?? UUID().uuidString)"; withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { selectedBook = book } }
    }
    
    private var coverSection: some View {
        let safeTitle = book.title ?? "未知书名"; let safeId = book.id ?? UUID().uuidString
        return ZStack {
            if selectedBook?.id != book.id {
                LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                    .frame(width: 100, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                    .shadow(color: Color.black.opacity(0.15), radius: 6, y: 3)
                    .matchedGeometryEffect(id: "timeline-\(safeId)", in: namespace)
            } else { Color.clear.frame(width: 100, height: 150) }
        }
        .scaleEffect(isHovered && selectedBook?.id != book.id ? 1.03 : 1.0)
    }
    
    private var textSection: some View {
        let safeTitle = book.title ?? "未知书名"; let safeAuthor = book.author ?? "未知作者"
        let notesCount = (book.notes?.count ?? 0) + (book.excerpts?.count ?? 0)
        
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(safeTitle).font(.system(size: 16, weight: .bold)).foregroundColor(isHovered ? .blue : .primary).lineLimit(2)
                
                HStack(alignment: .center, spacing: 8) {
                    Text(safeAuthor).font(.system(size: 13, weight: .medium)).foregroundColor(.secondary).lineLimit(1)
                    // ✨ 知识沉淀指示器：如果有笔记则点亮
                    if notesCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "pencil.and.outline").font(.system(size: 9))
                            Text("\(notesCount)").font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }
            ratingView
            tagView
            Spacer(minLength: 4)
            TimelineJourneyTicket(book: book, isHovered: isHovered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder private var ratingView: some View {
        let safeRating = book.rating ?? 0
        if safeRating > 0 {
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    // ✨ 星星变成纯正的 iOS 金黄色
                    ForEach(1 ... 5, id: \.self) { i in
                        Image(systemName: "star.fill").font(.system(size: 10))
                            .foregroundColor(i <= safeRating ? .yellow : Color.secondary.opacity(0.2))
                    }
                }
                Text(safeRating < ratingTexts.count ? ratingTexts[safeRating] : "")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.leading, 4)
                
                if safeRating == 5 { Image(systemName: "crown.fill").font(.system(size: 10)).foregroundColor(.orange) }
            }
        }
    }
    
    @ViewBuilder private var tagView: some View {
        let safeTags = book.tags ?? []
        if !safeTags.isEmpty {
            HStack(spacing: 6) {
                // ✨ Tag 采用靛青色调，摆脱灰暗
                ForEach(Array(safeTags.prefix(3)), id: \.self) { tag in
                    Text(tag).font(.system(size: 9, weight: .bold))
                        .foregroundColor(.indigo)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.indigo.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}

// MARK: - ✨ 时间轴历时胶囊 (复刻 iOS 青色质感)
private struct TimelineJourneyTicket: View {
    let book: Book; let isHovered: Bool
    var body: some View {
        let days = calculateDays(start: book.startTime, end: book.endTime)
        HStack(spacing: 0) {
            VStack(alignment: .center, spacing: 2) {
                Text("始于").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary.opacity(0.6))
                Text(formatShortDate(book.startTime)).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.secondary)
            }.frame(width: 40)
            
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    Circle().fill(Color.teal).frame(width: 4, height: 4)
                    Rectangle().fill(Color.teal.opacity(0.4)).frame(height: 1)
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundColor(.teal)
                }
                
                // ✨ 青色反白 Hover 动画
                Text("历时 \(days) 天")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isHovered ? .white : .teal)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(isHovered ? Color.teal : Color.teal.opacity(0.15))
                    .clipShape(Capsule())
                    .animation(.spring(response: 0.3), value: isHovered)
                    
            }.padding(.horizontal, 8)
            
            VStack(alignment: .center, spacing: 2) {
                Text("终于").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary.opacity(0.6))
                Text(formatShortDate(book.endTime)).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.secondary)
            }.frame(width: 40)
        }
    }

    private func formatShortDate(_ date: Date?) -> String {
        guard let d = date else { return "未知" }; let formatter = DateFormatter(); formatter.dateFormat = "MM.dd"; return formatter.string(from: d)
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
