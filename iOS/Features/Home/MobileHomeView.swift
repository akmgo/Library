#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 📚 Mobile 书架

private enum MobileLibraryFilter: String, CaseIterable, Identifiable {
    case all
    case planned
    case finished

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .planned: return "想读"
        case .finished: return "已读"
        }
    }

    var status: BookStatus? {
        switch self {
        case .all: return nil
        case .planned: return .planned
        case .finished: return .finished
        }
    }
}

struct MobileHomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @Query(sort: \ReadingSession.date, order: .reverse) private var sessions: [ReadingSession]

    @State private var activeBookDetail: Book?
    @State private var loggingBook: Book?
    @State private var filter: MobileLibraryFilter = .all

    private var sessionMap: [String: [ReadingSession]] {
        Dictionary(grouping: sessions, by: { $0.book?.id ?? "" })
    }

    private var sortedBooks: [Book] {
        books.sorted { lhs, rhs in
            priorityDate(for: lhs) > priorityDate(for: rhs)
        }
    }

    private var readingBooks: [Book] {
        sortedBooks.filter { $0.status == .reading }
    }

    private var visibleBooks: [Book] {
        sortedBooks.filter { book in
            filter.status.map { book.status == $0 } ?? true
        }
    }

    var body: some View {
        ZStack {
            AppColors.primaryBackground(for: colorScheme).ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if books.isEmpty {
                        EmptyStateView(
                            systemImage: "books.vertical",
                            title: "书架为空",
                            message: "添加一本书后，阅读记录和摘记会归到这里。",
                            iconSize: 46
                        )
                        .padding(.top, 120)
                    } else {
                        if filter == .all, !readingBooks.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                MobileLibrarySectionTitle(title: "在读", count: readingBooks.count)
                                LazyVStack(spacing: 12) {
                                    ForEach(readingBooks) { book in
                                        MobileReadingShelfCard(book: book) {
                                            loggingBook = book
                                        }
                                        .onTapGesture { activeBookDetail = book }
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            MobileLibraryFilterBar(selection: $filter)
                            MobileLibrarySectionTitle(title: filter == .all ? "全部书籍" : filter.title, count: visibleBooks.count)

                            if visibleBooks.isEmpty {
                                EmptyStateView(
                                    systemImage: "books.vertical",
                                    title: "\(filter.title)书架为空",
                                    message: "这里会展示对应状态的书。",
                                    iconSize: 38
                                )
                                .padding(.top, 32)
                            } else {
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: 22),
                                        GridItem(.flexible(), spacing: 22)
                                    ],
                                    spacing: 28
                                ) {
                                    ForEach(visibleBooks) { book in
                                        Button {
                                            activeBookDetail = book
                                        } label: {
                                            MobileShelfCover(book: book)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(book.title)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, 22)
                .padding(.bottom, AppSpacing.emptyState)
            }
        }
        .navigationDestination(item: $activeBookDetail) { book in
            MobileBookDetailView(book: book)
        }
        .sheet(item: $loggingBook) { book in
            MobileQuickReadingLogSheet(book: book)
        }
        .animation(.easeInOut(duration: 0.18), value: filter)
    }

    private func priorityDate(for book: Book) -> Date {
        sessionMap[book.id]?.map(\.startedAt).max()
            ?? book.lastReadAt
            ?? book.startDate
            ?? book.createdAt
    }
}

private struct MobileLibraryFilterBar: View {
    @Binding var selection: MobileLibraryFilter

    var body: some View {
        Picker("书籍状态", selection: $selection) {
            ForEach(MobileLibraryFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }
}

private struct MobileLibrarySectionTitle: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 21, weight: .semibold))
            Spacer()
            Text("\(count) 本")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct MobileReadingShelfCard: View {
    let book: Book
    let onAddLog: () -> Void

    private let coverWidth: CGFloat = 66
    private var coverHeight: CGFloat { coverWidth / (2.0 / 3.0) }

    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: 13) {
                BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                    .frame(width: coverWidth, height: coverHeight)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Text(book.author.isEmpty ? "未填写作者" : book.author)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Button(action: onAddLog) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 25, weight: .semibold))
                                .foregroundStyle(AppColors.readingAmber)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("添加阅读记录")
                    }

                    Spacer(minLength: 10)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(book.displayProgress)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        ProgressBarView(progress: book.progressRatio, height: 6)
                    }
                }
                .frame(height: coverHeight, alignment: .top)
            }
        }
    }
}

private struct MobileShelfCover: View {
    let book: Book

    var body: some View {
        BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
            .aspectRatio(2 / 3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
    }
}

private struct MobileQuickReadingLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let book: Book

    @State private var minutes: Int = 30
    @State private var endAmountText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("书籍") {
                    Text(book.title)
                    if !book.author.isEmpty {
                        Text(book.author).foregroundStyle(.secondary)
                    }
                }

                Section("阅读记录") {
                    Stepper(value: $minutes, in: 5...600, step: 5) {
                        Text("\(minutes) 分钟")
                    }

                    TextField("当前页码", text: $endAmountText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("添加阅读记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .onAppear {
                endAmountText = book.currentAmount > 0 ? "\(Int(book.currentAmount))" : ""
            }
        }
    }

    private func save() {
        let endedAt = Date()
        let duration = TimeInterval(minutes * 60)
        let startedAt = endedAt.addingTimeInterval(-duration)
        let endAmount = Double(endAmountText) ?? book.currentAmount

        try? ReadingDataService.shared.insertManualReadingSession(
            for: book,
            startedAt: startedAt,
            duration: duration,
            startAmount: book.currentAmount,
            endAmount: endAmount,
            context: modelContext
        )
        dismiss()
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
                                            selectedTab = 1
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

#if DEBUG
#Preview("主页") {
    PreviewWithData {
        MobileHomeView()
    }
}
#endif


#endif
