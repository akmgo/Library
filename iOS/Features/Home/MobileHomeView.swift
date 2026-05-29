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
        GeometryReader { geo in
            Color.clear.onChange(of: geo.frame(in: .named("homeScroll")).minY) { _, y in
                if y > 75 {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    NotificationCenter.default.post(name: .showGlobalSearch, object: nil)
                }
            }
        }
        .allowsHitTesting(false)
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
                print("❌ 想读转在读失败: \(error.localizedDescription)")
                return
            }
        }
        focusedReadingBookID = book.id
        activeBookDetail = book
    }
}


// MARK: - 🔍 独立全局搜索页

struct MobileGlobalSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    @Binding var selectedTab: Int
    @Binding var highlightedExcerptID: String?
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var isSearching = false
    
    @State private var resultBooks: [Book] = []
    @State private var resultExcerpts: [Excerpt] = []
    
    var body: some View {
        ZStack(alignment: .top) {
            // ================= 1. 全屏统一背景层 =================
            AppColors.primaryBackground(for: colorScheme)
                .ignoresSafeArea()
                .onTapGesture { closeSearch() }
            
            // ================= 2. 搜索结果层 =================
            VStack {
                if searchText.isEmpty {
                    VStack(spacing: AppSpacing.m) {
                        Spacer()
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundStyle(LinearGradient(colors: [.blue, .indigo], startPoint: .top, endPoint: .bottom))
                            .opacity(0.8)
                        Text("全局智能探索")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("检索书籍、摘录与笔记...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { closeSearch() }
                    
                } else if isSearching {
                    VStack(spacing: AppSpacing.m) {
                        ProgressView().padding(.top, 80)
                        Text("正在穿梭于档案库...").font(.system(size: 14)).foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else if resultBooks.isEmpty && resultExcerpts.isEmpty {
                    VStack(spacing: AppSpacing.m) {
                        Spacer()
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("未找到关于 “\(searchText)” 的内容")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { closeSearch() }
                    
                } else {
                    // ================= 核心结果列表 =================
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: AppSpacing.xxl) {
                            
                            // 📚 1. 书籍档案卡片
                            if !resultBooks.isEmpty {
                                searchResultSection(title: "书籍档案", count: resultBooks.count) {
                                    ForEach(resultBooks) { book in
                                        NavigationLink(destination: MobileBookDetailView(book: book)) {
                                            globalSearchBookCard(book: book)
                                        }
                                        .simultaneousGesture(TapGesture().onEnded { isSearchFocused = false })
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            if !resultExcerpts.isEmpty {
                                searchResultSection(title: "摘录笔记", count: resultExcerpts.count) {
                                    ForEach(resultExcerpts) { excerpt in
                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            isSearchFocused = false
                                            selectedTab = 2
                                            highlightedExcerptID = excerpt.id
                                            closeSearch()
                                        }) {
                                            globalSearchExcerptCard(excerpt: excerpt)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.l)
                        .padding(.top, 24)
                        .padding(.bottom, AppSpacing.emptyState)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 104)
            .padding(.bottom, AppSpacing.xl)
            
            // ================= 🌟 全局悬浮搜索框 =================
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.readingAmber)
                
                TextField("", text: $searchText, prompt: Text("搜索书籍和摘录...").foregroundColor(.secondary.opacity(0.6)))
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .onChange(of: searchText) { _, newValue in
                        triggerSearch(query: newValue)
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, AppSpacing.m)
            .frame(height: 58)
            .background(
                AppColors.secondaryBackground(for: colorScheme),
                in: RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                    .stroke(AppColors.innerStroke(for: colorScheme), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 18, y: 8)
            .padding(.horizontal, AppSpacing.l)
            .padding(.top, AppSpacing.l)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
        .background(
            Button("") { closeSearch() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
        )
    }
    
    // MARK: - 🎨 独立卡片化 UI 组件
    
    private func searchResultSection<Content: View>(title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(title) (\(count))")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: AppSpacing.m) {
                content()
            }
        }
    }
    
    private func globalSearchBookCard(book: Book) -> some View {
        AppCard {
            HStack(spacing: AppSpacing.m) {
                BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                    .frame(width: 40, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(book.title).font(.system(size: 16, weight: .bold)).foregroundColor(.primary)
                    HStack {
                        Text(book.author).font(.system(size: 13)).foregroundColor(.secondary)
                        Text("·")
                        Text(book.status.displayName).font(.system(size: 12, weight: .medium)).foregroundColor(.blue)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary.opacity(0.5))
            }
        }
        .contentShape(Rectangle())
    }
    
    private func globalSearchExcerptCard(excerpt: Excerpt) -> some View {
        let secondaryText = excerpt.book == nil ? excerpt.displayAuthor : excerpt.category.displayName

        return AppCard {
            HStack(alignment: .top, spacing: AppSpacing.m) {
                ZStack {
                    Circle().fill(excerpt.category.themeColor.opacity(0.15)).frame(width: 32, height: 32)
                    Image(systemName: excerpt.isNote ? "note.text" : "quote.bubble.fill")
                        .font(.system(size: 13))
                        .foregroundColor(excerpt.category.themeColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(excerpt.book == nil ? excerpt.displayTitle : "《\(excerpt.book?.title ?? "未知书籍")》")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(.primary)
                    Text(excerpt.content)
                        .font(.system(size: 14, design: .serif))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(3)
                        .lineSpacing(4)
                    Text(secondaryText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(excerpt.category.themeColor.opacity(0.8))
                }
                .padding(.top, 2)
                Spacer(minLength: 0)
            }
        }
        .contentShape(Rectangle())
    }
    
    // MARK: - ⚙️ 防抖搜索核心引擎
    
    private func triggerSearch(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else {
            isSearching = false
            resultBooks = []
            resultExcerpts = []
            return
        }
        
        isSearching = true
        searchTask?.cancel()
        
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            performSearch(query: trimmedQuery.lowercased())
        }
    }
    
    private func performSearch(query: String) {
        let allBooks = (try? modelContext.fetch(FetchDescriptor<Book>())) ?? []
        let allExcerpts = (try? modelContext.fetch(FetchDescriptor<Excerpt>())) ?? []
        
        let matchedBooks = allBooks.filter { book in
            SearchMatcher.matchesBook(book, query: query)
        }

        let matchedExcerpts = allExcerpts.filter { excerpt in
            SearchMatcher.matchesExcerpt(excerpt, query: query)
        }
        
        withAnimation(.easeOut(duration: 0.18)) {
            self.resultBooks = Array(matchedBooks.prefix(10))
            self.resultExcerpts = Array(matchedExcerpts.prefix(20))
            self.isSearching = false
        }
    }
    
    private func closeSearch() {
        searchTask?.cancel()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isSearchFocused = false
        withAnimation(.easeOut(duration: 0.18)) {
            isPresented = false
        }
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
