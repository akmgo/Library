#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 📱 Mobile 核心调度中心 (数据驱动版)

struct BookDetailPresentation: Identifiable {
    let id: String
}

struct MobileHomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - 📥 全局配置
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @Query(sort: \ReadingSession.date, order: .reverse) private var sessions: [ReadingSession]
    @Query(sort: \BookAnnotation.createdAt, order: .reverse) private var annotations: [BookAnnotation]
    
    // MARK: - 🎮 UI 交互状态
    @State private var showAddBookSheet = false
    @State private var showSettingsSheet = false
    
    // ✨ 全局沉浸式底部搜索状态
    @State private var showGlobalSearch = false
    
    @State private var activeBookDetail: BookDetailPresentation? = nil

    private var dashboard: ReadingStatsCalculator.DashboardSnapshot {
        ReadingStatsCalculator.dashboardSnapshot(
            books: books,
            sessions: sessions,
            annotations: annotations
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.primaryBackground(for: colorScheme).ignoresSafeArea()
                
                // ================= 📚 核心滑动大盘 =================
                ScrollView(.vertical, showsIndicators: false) {
                    
                    // ✨ 隐形下拉探测器：用力下拉唤起全屏搜索
                    GeometryReader { geo in
                        Color.clear.onChange(of: geo.frame(in: .named("homeScroll")).minY) { _, y in
                            if y > 75 && !showGlobalSearch {
                                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showGlobalSearch = true
                                }
                            }
                        }
                    }
                    .frame(height: 0)
                    
                    VStack(spacing: 24) {
                        // 🌟 1. 视觉锚点 (在读焦点)
                        if let heroBook = dashboard.activeReadingBook {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                activeBookDetail = BookDetailPresentation(id: heroBook.id)
                            }) {
                                MobileReadingHeroCard(book: heroBook)
                            }
                            .buttonStyle(.plain)
                        } else {
                            MobileEmptyReadingCard()
                        }
                        
                        // 📊 2. 数据大盘
                        MobileDashboardCard(
                            weekCount: dashboard.weekCount, monthlyDays: dashboard.monthlyDays, todayMinutes: dashboard.todayMinutes,
                            dailyGoal: dailyGoal, yearlyCount: dashboard.yearlyCount, yearTarget: yearTarget,
                            totalFinished: dashboard.totalFinished, totalLibrary: dashboard.totalLibrary
                        )
                        
                        // 🌊 3. 双周动能
                        MobileMomentumChartCard(dataPoints: dashboard.momentumPoints, totalMinutes: dashboard.momentumTotal)
                        
                        // 📚 4. 想读画廊
                        MobileQueueCarouselCard(displayBooks: dashboard.queueBooks)
                        
                        // 🧠 5. 深度复盘
                        MobileYearlyHeatmapCard(columns: dashboard.heatmapColumns, activeDays: dashboard.heatmapActiveDays)
                        MobileKnowledgeSpectrumCard(dataPoints: dashboard.spectrumPoints)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 60)
                }
                .coordinateSpace(name: "homeScroll")
                
                // ================= 🔍 独立底部搜索覆盖层 =================
                if showGlobalSearch {
                    MobileBottomSearchView(isPresented: $showGlobalSearch)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .zIndex(100)
                }
            }
            .navigationTitle(greeting)
            
            // ✨ 动态隐藏导航栏和底部 TabBar
            .toolbar(showGlobalSearch ? .hidden : .visible, for: .navigationBar)
            .toolbar(showGlobalSearch ? .hidden : .visible, for: .tabBar)
            
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showAddBookSheet = true }) {
                            Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                        }
                        Button(action: { showSettingsSheet = true }) {
                            Image(systemName: "gearshape.fill").foregroundColor(.secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddBookSheet) { MobileBookEditorSheet() }
            .sheet(isPresented: $showSettingsSheet) { MobileSettingsView() }
            .groupBoxStyle(NativeWidgetGroupBoxStyle())
            
            .sheet(item: $activeBookDetail) { presentation in
                if let book = book(withID: presentation.id) {
                    MobileBookDetailView(book: book)
                }
            }
        }
    }
}

private extension MobileHomeView {
    func book(withID id: String) -> Book? {
        books.first { $0.id == id }
    }
}


// MARK: - 🔍 独立全局搜索页

struct MobileAnnotationSearchResult: Identifiable {
    let id = UUID()
    let book: Book
    let annotation: BookAnnotation
}

struct MobileBottomSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var isSearching = false
    
    @State private var resultBooks: [Book] = []
    @State private var resultAnnotations: [MobileAnnotationSearchResult] = []
    @State private var resultSnippets: [Snippet] = []
    
    // ✨ 核心重构：统一使用一个通用阅读载荷来接管所有的全屏阅读
    @State private var readingPayload: MobileFullscreenPayload? = nil
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // ================= 1. 全屏统一背景层 =================
            Color.black.opacity(colorScheme == .dark ? 0.35 : 0.15)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { closeSearch() }
            
            // ================= 2. 搜索结果层 =================
            VStack {
                if searchText.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundStyle(LinearGradient(colors: [.blue, .indigo], startPoint: .top, endPoint: .bottom))
                            .opacity(0.8)
                        Text("全局智能探索")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("检索书籍、书中摘录与日常碎片...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { closeSearch() }
                    
                } else if isSearching {
                    VStack(spacing: 16) {
                        ProgressView().padding(.top, 80)
                        Text("正在穿梭于档案库...").font(.system(size: 14)).foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else if resultBooks.isEmpty && resultAnnotations.isEmpty && resultSnippets.isEmpty {
                    VStack(spacing: 16) {
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
                        VStack(spacing: 32) {
                            
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
                            
                            // 🔖 2. 书中摘录卡片
                            if !resultAnnotations.isEmpty {
                                searchResultSection(title: "书中摘录", count: resultAnnotations.count) {
                                    ForEach(resultAnnotations) { item in
                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            isSearchFocused = false
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                // 转化为通用 payload
                                                readingPayload = createPayload(book: item.book, annotation: item.annotation)
                                            }
                                        }) {
                                            globalSearchAnnotationCard(book: item.book, annotation: item.annotation)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            // 🖋️ 3. 日常摘录卡片
                            if !resultSnippets.isEmpty {
                                searchResultSection(title: "日常摘录", count: resultSnippets.count) {
                                    ForEach(resultSnippets) { snippet in
                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            isSearchFocused = false
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                // 转化为通用 payload
                                                readingPayload = createPayload(from: snippet)
                                            }
                                        }) {
                                            globalSearchSnippetCard(snippet: snippet)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 120)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 80)
            
            // ================= 🌟 独立悬浮液态玻璃搜索框 =================
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.blue.opacity(0.7))
                
                TextField("", text: $searchText, prompt: Text("探索书籍、笔记与碎片...").foregroundColor(.secondary.opacity(0.6)))
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
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(colorScheme == .dark ? Color(red: 0.05, green: 0.06, blue: 0.08).opacity(0.6) : Color.white.opacity(0.7))
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.black.opacity(colorScheme == .dark ? 0.2 : 0.03), lineWidth: 3).blur(radius: 2).offset(y: 1).mask(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(LinearGradient(colors: [colorScheme == .dark ? .white.opacity(0.15) : .black.opacity(0.05), .clear, colorScheme == .dark ? .white.opacity(0.03) : .black.opacity(0.01)], startPoint: .top, endPoint: .bottom), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.1), radius: 12, y: 6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            // ================= 🌟 4. 统一全屏阅读器层 =================
            if let payload = readingPayload {
                MobileUnifiedFullscreenReadingView(payload: payload) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        readingPayload = nil
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(200)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
    }
    
    // MARK: - 🗂️ 数据适配器 (Mapper)
    
    private func createPayload(book: Book, annotation: BookAnnotation) -> MobileFullscreenPayload {
        let validAuthor = book.author.trimmingCharacters(in: .whitespaces).isEmpty || book.author == "佚名" ? nil : book.author
        return MobileFullscreenPayload(
            title: book.title,
            author: validAuthor,
            content: annotation.content,
            alignment: .leading,
            isIndented: true,
            footer: "—— \(annotation.isNote ? "笔记" : "摘录")于《\(book.title)》",
            annotation: nil
        )
    }
    
    private func createPayload(from snippet: Snippet) -> MobileFullscreenPayload {
        let showHeader = [.poetry, .lyric, .prose].contains(snippet.category)
        let authorText = "\(snippet.author)\(snippet.dynasty.isEmpty ? "" : " (\(snippet.dynasty))")"
        let validAuthor = (showHeader && !authorText.trimmingCharacters(in: .whitespaces).isEmpty && snippet.author != "佚名") ? authorText : nil
        
        let footerText: String? = {
            if snippet.category == .quote { return "—— \(snippet.author)" }
            if snippet.category == .movie { return "—— \(snippet.author)（\(snippet.title)）" }
            return nil
        }()
        
        return MobileFullscreenPayload(
            title: showHeader ? snippet.title : nil,
            author: validAuthor,
            content: snippet.content,
            alignment: snippet.category == .poetry ? .center : .leading,
            isIndented: [.lyric, .prose].contains(snippet.category),
            footer: footerText,
            annotation: snippet.annotation.isEmpty ? nil : snippet.annotation
        )
    }
    
    // MARK: - 🎨 独立卡片化 UI 组件
    
    private func searchResultSection<Content: View>(title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(title) (\(count))")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 16) {
                content()
            }
        }
    }
    
    private func globalSearchBookCard(book: Book) -> some View {
        HStack(spacing: 16) {
            BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
            
            VStack(alignment: .leading, spacing: 4) {
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
        .padding(14)
        .background(AppColors.secondaryBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
        .contentShape(Rectangle())
    }
    
    private func globalSearchAnnotationCard(book: Book, annotation: BookAnnotation) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: annotation.isNote ? "square.and.pencil" : "highlighter")
                    .font(.system(size: 13))
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title).font(.system(size: 15, weight: .bold, design: .serif)).foregroundColor(.primary)
                Text(annotation.content)
                    .font(.system(size: 14, design: .serif))
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(3)
                    .lineSpacing(4)
            }
            .padding(.top, 2)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(AppColors.secondaryBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
        .contentShape(Rectangle())
    }
    
    private func globalSearchSnippetCard(snippet: Snippet) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle().fill(snippet.category.themeColor.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: "quote.bubble.fill").font(.system(size: 13)).foregroundColor(snippet.category.themeColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(snippet.title).font(.system(size: 15, weight: .bold, design: .serif)).foregroundColor(.primary)
                Text(snippet.content)
                    .font(.system(size: 14, design: .serif))
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(3)
                    .lineSpacing(4)
            }
            .padding(.top, 2)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(AppColors.secondaryBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
        .contentShape(Rectangle())
    }
    
    // MARK: - ⚙️ 防抖搜索核心引擎
    
    private func triggerSearch(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else {
            isSearching = false
            resultBooks = []
            resultAnnotations = []
            resultSnippets = []
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
        let allSnippets = (try? modelContext.fetch(FetchDescriptor<Snippet>())) ?? []
        
        let matchedBooks = allBooks.filter { book in
            book.title.localizedStandardContains(query) ||
            book.author.localizedStandardContains(query)
        }
        
        var matchedAnnotations: [MobileAnnotationSearchResult] = []
        for book in allBooks {
            if let annotations = book.annotations {
                for annotation in annotations {
                    if annotation.content.localizedStandardContains(query) {
                        matchedAnnotations.append(MobileAnnotationSearchResult(book: book, annotation: annotation))
                    }
                }
            }
        }
        
        let matchedSnippets = allSnippets.filter { snippet in
            snippet.title.localizedStandardContains(query) ||
            snippet.author.localizedStandardContains(query) ||
            snippet.content.localizedStandardContains(query) ||
            snippet.annotation.localizedStandardContains(query)
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            self.resultBooks = matchedBooks
            self.resultAnnotations = matchedAnnotations
            self.resultSnippets = matchedSnippets
            self.isSearching = false
        }
    }
    
    private func closeSearch() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isSearchFocused = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

// MARK: - 📖 统一通用层：沉浸式全屏阅读视图

// 💡 这是一个完全解耦的数据模型，任何符合该格式的文字块都可以被此视图渲染
struct MobileFullscreenPayload {
    var title: String?
    var author: String?
    var content: String
    var alignment: TextAlignment = .leading
    var isIndented: Bool = true
    var footer: String? = nil
    var annotation: String? = nil
}

struct MobileUnifiedFullscreenReadingView: View {
    let payload: MobileFullscreenPayload
    var onClose: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private var displayContent: String {
        payload.isIndented
            ? payload.content.components(separatedBy: .newlines).map { "\u{3000}\u{3000}" + $0 }.joined(separator: "\n")
            : payload.content
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppColors.primaryBackground(for: colorScheme).ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 32) {
                    
                    // 1. 头部 (按需显示)
                    if payload.title != nil || payload.author != nil {
                        VStack(spacing: 12) {
                            if let title = payload.title {
                                Text(title)
                                    .font(.system(size: 28, weight: .heavy, design: .serif))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                            }
                            if let author = payload.author {
                                Text(author)
                                    .font(.system(size: 14, weight: .medium, design: .serif))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 80)
                    } else {
                        Spacer().frame(height: 60)
                    }
                    
                    // 2. 核心正文
                    Text(displayContent)
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .lineSpacing(14)
                        .foregroundColor(.primary.opacity(0.9))
                        .multilineTextAlignment(payload.alignment)
                        .frame(maxWidth: .infinity, alignment: payload.alignment == .center ? .center : .leading)
                    
                    // 3. 尾部落款
                    if let footer = payload.footer {
                        HStack {
                            Spacer()
                            Text(footer)
                                .font(.system(size: 14, weight: .medium, design: .serif))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 16)
                    }
                    
                    // 4. 专属注解
                    if let annotation = payload.annotation {
                        VStack(alignment: .leading, spacing: 12) {
                            Divider()
                            Text("注解 / 释义").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary)
                            Text(annotation)
                                .font(.system(size: 14, design: .serif))
                                .lineSpacing(8)
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
                .frame(maxWidth: .infinity)
            }
            
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onClose()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(Circle())
            }
            .padding(.trailing, 20)
            .padding(.top, 20)
        }
    }
}

// MARK: - 🎨 辅助计算属性

extension MobileHomeView {
    private var dailyGoal: Int { configs.first?.dailyMinutesGoal ?? 30 }
    private var yearTarget: Int { configs.first?.yearlyBooksGoal ?? 50 }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 9 { return "早安，纪元" }
        else if hour < 14 { return "午后，纪元" }
        else if hour < 19 { return "傍晚，纪元" }
        else { return "入夜，纪元" }
    }
}
#endif
