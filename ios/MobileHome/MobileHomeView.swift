#if os(iOS)
internal import Combine
import SwiftData
import SwiftUI

// MARK: - 👑 iOS 核心调度中心 (沉浸式主页)

/// iOS 端的应用核心入口与数据中枢面板。
///
/// **架构与职责：**
/// 该视图基于 `NavigationStack` 搭建，通过纵向滚动的堆叠卡片 (Card) 来呈现各个维度的数据大盘。
/// - **顶层路由**：掌管新建图书 (`MobileBookEditorSheet`) 和设置页面 (`MobileSettingsView`) 的弹窗调度。
/// - **数据分发**：统一利用 `@Query` 从 SwiftData 获取全局数据，并下发给各个功能卡片，避免子组件重复查询引发的性能消耗。
/// - **全局样式**：为所有的子卡片注入了高定版的毛玻璃拟物样式 (`NativeWidgetGroupBoxStyle`)。
struct MobileHomeView: View {
    @Query var allBooks: [Book]
    @Query var allRecords: [ReadingRecord]
    @Query var allExcerpts: [Excerpt]
    
    // MARK: - 弹窗状态控制
    @State private var showAddBookSheet = false
    @State private var showSettingsSheet = false
    
    // MARK: - 数据提取引擎
    
    /// 智能提取当前最优先的“在读焦点”书籍。
    ///
    /// - 提取逻辑：筛选出所有 `status == .reading` 的书籍，并以其最近一条打卡记录的日期作为倒序排序依据，取最新鲜的一本。
    var activeReadingBook: Book? {
        allBooks
            .filter { $0.status == .reading }
            .max { b1, b2 in
                let date1 = b1.readingRecords?.compactMap(\.date).max() ?? b1.startTime ?? .distantPast
                let date2 = b2.readingRecords?.compactMap(\.date).max() ?? b2.startTime ?? .distantPast
                return date1 < date2
            }
    }

    /// 提取所有已读完的书籍，供底部知识图谱统计使用。
    var readBooks: [Book] {
        allBooks.filter { $0.status == .finished }
    }

    /// 提取所有未读的书籍，供横滑想读列车使用。
    var unreadBooks: [Book] {
        allBooks.filter { $0.status == .unread }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // 🌟 层级 1：视觉锚点 (在读焦点 & 控制台)
                    if let heroBook = activeReadingBook {
                        NavigationLink(destination: MobileBookDetailView(book: heroBook)) {
                            MobileReadingHeroCard(book: heroBook)
                        }
                        .buttonStyle(.plain)
                                                                    
                        HStack(spacing: 16) {
                            MobileFocusTimerCard(book: heroBook, allRecords: allRecords)
                            MobileManualLogCard(defaultBook: heroBook, allBooks: allBooks)
                        }
                    } else {
                        MobileEmptyReadingCard()
                    }
                    
                    // 📊 层级 2：核心数据大盘 (完美复刻桌面端圆环看板)
                    MobileDashboardCard(allBooks: allBooks, allRecords: allRecords)
                    
                    // 🌊 层级 3：双周阅读动能 (完美复刻小组件动能图)
                    MobileMomentumChartCard(allRecords: allRecords)
                    
                    // 📚 层级 4：想读画廊 (横向滚动)
                    MobileQueueCarouselCard(unreadBooks: unreadBooks)
                    
                    // 🧠 层级 5：深度复盘区 (热力图 + 知识图谱)
                    MobileYearlyHeatmapCard(allRecords: allRecords)
                    MobileKnowledgeSpectrumCard(readBooks: readBooks)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 60)
            }
            // 使用 iOS 专为卡片式布局设计的原生深浅色底层
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("阅读纪元")
            .toolbar {
                // ✨ 右上角全局导航按钮
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showAddBookSheet = true }) {
                            Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                        }
                        Button(action: { showSettingsSheet = true }) {
                            Image(systemName: "gearshape.fill").foregroundColor(.secondary)
                        }
                    }
                    .font(.system(size: 20))
                }
            }
            // 💡 弹窗引擎池
            .sheet(isPresented: $showAddBookSheet) {
                MobileBookEditorSheet()
            }
            .sheet(isPresented: $showSettingsSheet) {
                MobileSettingsView()
            }
            // 💡 全局注入你的神仙级 GroupBox 样式！
            .groupBoxStyle(NativeWidgetGroupBoxStyle())
        }
    }
}
#endif
