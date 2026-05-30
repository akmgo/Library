#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 📱 Mobile 核心调度中心 (数据驱动版)

struct MobileHomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    // MARK: - 📥 全局配置
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @Query(sort: \ReadingSession.date, order: .reverse) private var sessions: [ReadingSession]
    @Query(sort: \Excerpt.createdAt, order: .reverse) private var excerpts: [Excerpt]
    
    // MARK: - 🎮 UI 交互状态
    @State private var activeBookDetail: Book? = nil
    @State private var focusedReadingBookID: String?
    @State private var dashboard: ReadingStatsCalculator.DashboardSnapshot = .empty
    @State private var cachedOrderedReadingBooks: [Book] = []
    @State private var cachedTodaySeconds: TimeInterval = 0

    private var homeFP: String {
        let latestSession = sessions.last?.startedAt.timeIntervalSince1970 ?? 0
        return "\(books.count)-\(sessions.count)-\(excerpts.count)-\(latestSession)"
    }

    var body: some View {
        ZStack {
            AppColors.primaryBackground(for: colorScheme).ignoresSafeArea()
            
            // ================= 📚 核心滑动大盘 =================
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: AppSpacing.xl) {
                    
                    // 📊 2. 数据大盘
                    MobilePageStatsHeader(items: homeStats)

                    LazyVStack(spacing: AppSpacing.xl) {

                        // 🌟 1. 视觉锚点 (在读焦点)
                        if let heroBook = focusedReadingBook {
                            MobileReadingHeroCard(
                                book: heroBook,
                                secondaryBooks: secondaryReadingBooks,
                                onTapDetail: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    activeBookDetail = heroBook
                                },
                                onSelectSecondaryBook: { candidate in
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        focusedReadingBookID = candidate.id
                                    }
                                }
                            )
                        } else {
                            MobileEmptyReadingCard()
                        }

                        // ⏱️ 3. 阅读计时
                        MobileReadingTimerCard(
                            book: focusedReadingBook,
                            todayTotalSeconds: todayTotalSeconds
                        )

                        // 🌊 4. 双周动能
                        SharedMomentumChart(dataPoints: dashboard.momentumPoints, totalMinutes: dashboard.momentumTotal)

                        // 💭 5. 思想共鸣
                        SharedResonanceCard(excerpts: dashboard.resonancePoints)

                        // 📚 6. 想读画廊
                        SharedQueueBookshelf(displayBooks: dashboard.queueBooks) { tappedBook in
                            startReadingFromQueue(tappedBook)
                        }

                        // 🧠 7. 深度复盘
                        SharedKnowledgeSpectrum(dataPoints: dashboard.spectrumPoints)
                    }
                    .padding(.horizontal, AppSpacing.l)
                }
                .padding(.bottom, AppSpacing.emptyState)
                .background(alignment: .top) {
                    pullToSearchDetector
                }
            }
            .coordinateSpace(name: "homeScroll")
        }
        .onAppear { refreshHomeData() }
        .onChange(of: homeFP) { _, _ in refreshHomeData() }
        .navigationDestination(item: $activeBookDetail) { book in
            MobileBookDetailView(book: book)
        }
    }

    private var pullToSearchDetector: some View {
        Color.clear.frame(height: 0)
    }
}

private extension MobileHomeView {
    // MARK: - 在读焦点管理

    private var orderedReadingBooks: [Book] { cachedOrderedReadingBooks }

    private var focusedReadingBook: Book? {
        if let focusedReadingBookID,
           let focused = orderedReadingBooks.first(where: { $0.id == focusedReadingBookID }) {
            return focused
        }
        return orderedReadingBooks.first
    }

    private var secondaryReadingBooks: [Book] {
        guard let focusedReadingBook else { return [] }
        return Array(orderedReadingBooks.filter { $0.id != focusedReadingBook.id }.prefix(3))
    }

    private var todayTotalSeconds: TimeInterval { cachedTodaySeconds }

    private func startReadingFromQueue(_ book: Book) {
        if book.status == .planned {
            do {
                try ReadingDataService.shared.markBookStartedFromQueue(book, context: modelContext)
            } catch {
                return
            }
        }
        focusedReadingBookID = book.id
        activeBookDetail = book
    }
}


// MARK: - 🎨 辅助计算属性

extension MobileHomeView {
    @MainActor
    private func refreshHomeData() {
        dashboard = ReadingStatsCalculator.dashboardSnapshot(
            books: books, sessions: sessions, excerpts: excerpts
        )
        let sessionMap = Dictionary(grouping: sessions, by: { $0.book?.id ?? "" })
        cachedOrderedReadingBooks = books
            .filter { $0.status == .reading }
            .sorted { lhs, rhs in
                let lDate = sessionMap[lhs.id]?.map(\.startedAt).max()
                    ?? lhs.lastReadAt ?? lhs.startDate ?? lhs.createdAt
                let rDate = sessionMap[rhs.id]?.map(\.startedAt).max()
                    ?? rhs.lastReadAt ?? rhs.startDate ?? rhs.createdAt
                return lDate > rDate
            }
        let calendar = Calendar.current
        let today = Date()
        cachedTodaySeconds = sessions
            .filter { calendar.isDate($0.date, inSameDayAs: today) }
            .reduce(0) { $0 + max($1.duration, 0) }
    }

    private var dailyGoal: Int { configs.first?.dailyMinutesGoal ?? 30 }
    private var yearTarget: Int { configs.first?.yearlyBooksGoal ?? 50 }
    private var libraryTarget: Int { configs.first?.libraryBooksGoal ?? 100 }

    private var homeStats: [PageStatItemData] {
        [
            PageStatItemData(title: "本周打卡", value: "\(dashboard.weekCount)/7", color: .pink),
            PageStatItemData(title: "本月历程", value: "\(dashboard.monthlyDays)/30", color: AppColors.readingAmber),
            PageStatItemData(title: "年度阅卷", value: "\(dashboard.yearlyCount)/\(yearTarget)", color: .teal),
            PageStatItemData(title: "馆藏进度", value: "\(dashboard.totalFinished)/\(libraryTarget)", color: .indigo),
        ]
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 9 { return "早安，纪元" }
        else if hour < 14 { return "午后，纪元" }
        else if hour < 19 { return "傍晚，纪元" }
        else { return "入夜，纪元" }
    }
}

#if DEBUG
#Preview("主页") {
    PreviewWithData {
        MobileHomeView()
    }
}
#endif


#endif
