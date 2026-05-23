#if os(macOS)
import SwiftData
import SwiftUI

// MARK: - 🌊 流动书房主页 (UI 画布层)

struct HomeView: View {
    // MARK: - 📥 全局配置
    
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @Query(sort: \ReadingSession.date, order: .reverse) private var sessions: [ReadingSession]
    @Query(sort: \Excerpt.createdAt, order: .reverse) private var excerpts: [Excerpt]
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - 🎮 视图路由状态
    
    @Binding var selectedBook: Book? // 仅保留详情页绑定
    @State private var focusedReadingBookID: String?
    
    private var dashboard: ReadingStatsCalculator.DashboardSnapshot {
        ReadingStatsCalculator.dashboardSnapshot(
            books: books,
            sessions: sessions,
            excerpts: excerpts
        )
    }

    private var orderedReadingBooks: [Book] {
        books
            .filter { $0.status == .reading }
            .sorted { lhs, rhs in
                readingPriorityDate(for: lhs) > readingPriorityDate(for: rhs)
            }
    }

    private var focusedReadingBook: Book? {
        if let focusedReadingBookID,
           let focused = orderedReadingBooks.first(where: { $0.id == focusedReadingBookID }) {
            return focused
        }
        return orderedReadingBooks.first
    }

    private var secondaryReadingBooks: [Book] {
        guard let focusedReadingBook else { return Array(orderedReadingBooks.prefix(3)) }
        return Array(orderedReadingBooks.filter { $0.id != focusedReadingBook.id }.prefix(3))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ZStack {
                LazyVStack(spacing: 24) {
                    Spacer().frame(height: 120)
                        
                    // 🌟 Row 1: 核心操作区 (Hero Section) - UI 布局严格保留你的原样
                    Group {
                        if let heroBook = focusedReadingBook {
                            HStack(spacing: 24) {
                                ReadingHero(
                                    book: heroBook,
                                    secondaryBooks: secondaryReadingBooks,
                                    onOpenBookDetail: {
                                        selectedBook = heroBook
                                    },
                                    onSelectSecondaryBook: { book in
                                        focusedReadingBookID = book.id
                                    }
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)

                                ReadingTimerCard(book: heroBook, todayTotalSeconds: todayTotalSeconds)
                                    .frame(width: 280)
                            }
                        } else {
                            HStack(spacing: 24) {
                                EmptyReadingHero()
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                EmptyReadingTimerCard()
                                    .frame(width: 280)
                            }
                        }
                    }
                    .frame(height: 320)
                        
                    // 🌟 Row 2: 视觉数据双轨
                    VStack(spacing: 24) {
                        MomentumChart(dataPoints: dashboard.momentumPoints, totalMinutes: dashboard.momentumTotal)
                        HeatmapRibbon(columns: dashboard.heatmapColumns, activeDays: dashboard.heatmapActiveDays)
                    }
                        
                    // 🌟 Row 3: 思想碰撞与未来队列
                    HStack(spacing: 24) {
                        ResonanceWave(excerpts: dashboard.resonancePoints)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // ✨ 点击闭包：处理想读变在读，并发送阅读通知
                        QueueBookshelf(displayBooks: dashboard.queueBooks) { tappedBook in
                            startReadingFromQueue(book: tappedBook)
                        }
                    }
                    .frame(height: 300)

                    // 🌟 Row 4: 底部基石
                    KnowledgeSpectrum(dataPoints: dashboard.spectrumPoints)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 80)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .overlay(alignment: .top) {
            AppPageHeader(
                contentID: "\(greeting)-\(dashboard.weekCount)-\(dashboard.monthlyDays)-\(dashboard.yearlyCount)"
            ) {
                AppHeaderTitle("阅读主页", subtitle: greeting)
            } trailingContent: {
                AppHeaderStatsView(homeHeaderStats)
            }
        }
    }
}

// MARK: - ⚙️ 异步数据调度引擎

extension HomeView {
    
    @MainActor
    private func startReadingFromQueue(book: Book) {
        if book.status == .planned {
            try? ReadingDataService.shared.markBookStartedFromQueue(book, context: modelContext)
        }
        focusedReadingBookID = book.id
        selectedBook = book
    }

    private func readingPriorityDate(for book: Book) -> Date {
        let latestSessionDate = sessions
            .filter { $0.book?.id == book.id }
            .map(\.startedAt)
            .max()
        return latestSessionDate ?? book.lastReadAt ?? book.startDate ?? book.createdAt
    }
}

extension HomeView {
    private var dailyTarget: Int { max(configs.first?.dailyMinutesGoal ?? 30, 1) }

    private var todayTotalSeconds: TimeInterval {
        let calendar = Calendar.current
        let today = Date()
        return sessions.filter {
            calendar.isDate($0.date, inSameDayAs: today)
        }.reduce(0) {
            $0 + max($1.duration, 0)
        }
    }
    private var yearTarget: Int { configs.first?.yearlyBooksGoal ?? 50 }
    private var homeHeaderStats: [AppHeaderStatItem] {
        [
            AppHeaderStatItem(current: dashboard.weekCount, target: 7, label: "本周打卡"),
            AppHeaderStatItem(current: dashboard.monthlyDays, target: 30, label: "本月历程"),
            AppHeaderStatItem(current: dashboard.yearlyCount, target: yearTarget, label: "年度阅卷")
        ]
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 9 { return "晨光正好，宜卷开新章。" }
        else if hour < 14 { return "午后静谧，在文字中漫步。" }
        else if hour < 19 { return "夕阳西下，且将思想沉淀。" }
        else { return "夜色温润，伴书香入眠。" }
    }
}

#endif
