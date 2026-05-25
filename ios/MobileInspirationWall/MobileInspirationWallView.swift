#if os(iOS)
import SwiftData
import SwiftUI

// ============================================================================
// MARK: - 🌊 2. 灵感画廊 (核心视图)
// ============================================================================

struct MobileInspirationWallView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query var allExcerpts: [Excerpt]

    @State private var displayExcerpts: [ExcerptListItem] = []
    @State private var filterCategory: ExcerptCategory? = nil
    @State private var sortKey: AnnotationSortKey = .newest
    @State private var isEditing = false
    @State private var selectedIDs: Set<String> = []
    @State private var showBatchDeleteAlert = false
    @State private var showAddExcerpt = false

    private var annotationFingerprint: String {
        allExcerpts
            .map { "\($0.id)|\($0.type.rawValue)|\($0.createdAt.timeIntervalSince1970)|\($0.content.hashValue)|\($0.book?.id ?? "")" }
            .joined(separator: ";")
            + "|\(filterCategory?.rawValue ?? "all")|\(sortKey)"
    }

    private var excerptStats: [PageStatItemData] {
        let total = allExcerpts.count
        let bookExcerptCount = allExcerpts.filter { $0.category == .bookExcerpt }.count
        let uniqueBooks = Set(allExcerpts.compactMap { $0.book?.title }).count
        let thisWeek = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let newThisWeek = allExcerpts.filter { $0.createdAt >= thisWeek }.count

        return [
            PageStatItemData(title: "全部摘录", value: "\(total)", color: .indigo),
            PageStatItemData(title: "书中摘录", value: "\(bookExcerptCount)", color: AppColors.readingAmber),
            PageStatItemData(title: "知识源泉", value: "\(uniqueBooks)", color: .teal),
            PageStatItemData(title: "本周新增", value: "\(newThisWeek)", color: .pink),
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppColors.primaryBackground(for: colorScheme).ignoresSafeArea()

                GeometryReader { geometry in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: AppSpacing.xl) {
                            MobilePageStatsHeader(items: excerptStats)

                            if displayExcerpts.isEmpty {
                                emptyStateView
                            } else {
                                singleColumnList(containerWidth: geometry.size.width)
                            }
                        }
                        .padding(.bottom, AppSpacing.emptyState)
                    }
                }
            }
            .toolbar { excerptsToolbar }
            .alert("批量删除", isPresented: $showBatchDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive, action: batchDelete)
            } message: {
                Text("确定删除选中的 \(selectedIDs.count) 条摘录吗？此操作不可撤销。")
            }
            .sheet(isPresented: $showAddExcerpt) {
                MobileExcerptEditorSheet(isPresented: $showAddExcerpt)
            }
            .onChange(of: annotationFingerprint) { _, _ in refreshData(animate: true) }
            .onAppear { refreshData(animate: false) }
        }
    }

    @ToolbarContentBuilder
    private var excerptsToolbar: some ToolbarContent {
        if isEditing {
            editToolbar
        } else {
            normalToolbar
        }
    }

    @ToolbarContentBuilder
    private var editToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("取消") { withAnimation { exitEditMode() } }
        }
        ToolbarItem(placement: .principal) {
            Text(selectedIDs.isEmpty ? "选择摘录" : "已选 \(selectedIDs.count) 条")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
        }
        if !selectedIDs.isEmpty {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showBatchDeleteAlert = true }) {
                    Image(systemName: "trash").foregroundColor(AppColors.danger)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var normalToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 14) {
                Button(action: { withAnimation { isEditing = true } }) {
                    Image(systemName: "checklist")
                }
                categoryFilterMenu
                sortMenu
                Button(action: { showAddExcerpt = true }) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private var categoryFilterMenu: some View {
        Menu {
            Button(action: { filterCategory = nil }) {
                HStack {
                    Text("全部分类")
                    if filterCategory == nil { Image(systemName: "checkmark") }
                }
            }
            ForEach(ExcerptCategory.allCases, id: \.self) { cat in
                Button(action: { filterCategory = cat }) {
                    HStack {
                        Text(cat.displayName)
                        if filterCategory == cat { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }

    private var sortMenu: some View {
        Menu {
            Button(action: { sortKey = .newest }) {
                HStack {
                    Text("最新在前")
                    if sortKey == .newest { Image(systemName: "checkmark") }
                }
            }
            Button(action: { sortKey = .oldest }) {
                HStack {
                    Text("最早在前")
                    if sortKey == .oldest { Image(systemName: "checkmark") }
                }
            }
            Button(action: { sortKey = .bookTitle }) {
                HStack {
                    Text("按书名")
                    if sortKey == .bookTitle { Image(systemName: "checkmark") }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }


    // MARK: - 布局

    private func singleColumnList(containerWidth: CGFloat) -> some View {
        LazyVStack(spacing: AppSpacing.m) {
            ForEach(displayExcerpts) { excerpt in
                selectableExcerptCard(excerpt)
            }
        }
        .frame(width: max(320, containerWidth - AppSpacing.l * 2))
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, AppSpacing.l)
    }

    @ViewBuilder
    private func selectableExcerptCard(_ excerpt: ExcerptListItem) -> some View {
        if isEditing {
            Button(action: {
                withAnimation(.spring(response: 0.25)) { toggleSelection(excerpt.id) }
            }) {
                MobileUnifiedExcerptCardView(
                    excerpt: excerpt
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .stroke(selectedIDs.contains(excerpt.id) ? Color.blue : Color.clear, lineWidth: 3)
                )
            }
            .buttonStyle(.plain)
        } else {
            MobileUnifiedExcerptCardView(
                excerpt: excerpt
            )
        }
    }
    
    // MARK: - ⚙️ 核心数据引擎
    
    private func refreshData(animate: Bool) {
        let results = ReadingStatsCalculator.inspirationSnapshot(
            excerpts: allExcerpts,
            type: filterCategory,
            searchText: "",
            sortKey: sortKey,
            randomize: false
        ).excerpts

        if animate {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { self.displayExcerpts = results }
        } else {
            self.displayExcerpts = results
        }
    }

    // MARK: - 批量操作

    private func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) }
        else { selectedIDs.insert(id) }
    }

    private func exitEditMode() {
        isEditing = false
        selectedIDs = []
    }

    private func batchDelete() {
        let targets = allExcerpts.filter { selectedIDs.contains($0.id) }
        try? ReadingDataService.shared.deleteExcerpts(targets, context: modelContext)
        exitEditMode()
    }
    
    // MARK: - 内部组件与逻辑
    
    private var emptyStateView: some View {
        EmptyStateView(
            systemImage: "leaf",
            title: "空空如也",
            message: "多读书，多记录，这里会长出智慧的森林。",
            minHeight: 320
        )
        .padding(.top, 24)
    }
    
}

private struct MobileInkExcerptHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MobileUnifiedExcerptCardView: View {
    let excerpt: ExcerptListItem
    @State private var naturalInkHeight: CGFloat = 0
    @State private var isInkFullscreenPresented = false

    private let inkMaxHeight: CGFloat = 700
    private var isInkTruncated: Bool { naturalInkHeight > inkMaxHeight }
    
    var body: some View {
        inkGalleryCard
        .fullScreenCover(isPresented: $isInkFullscreenPresented) {
            MobileInkExcerptFullscreenView(excerpt: excerpt) {
                isInkFullscreenPresented = false
            }
        }
    }

    private var inkGalleryCard: some View {
        ZStack(alignment: .bottom) {
            inkTextLayout
                .padding(.horizontal, AppSpacing.l)
                .padding(.vertical, AppSpacing.xl)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(key: MobileInkExcerptHeightPreferenceKey.self, value: geometry.size.height)
                    }
                )
                .frame(height: isInkTruncated ? inkMaxHeight : nil, alignment: .top)
                .mask {
                    if isInkTruncated {
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.75),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else {
                        Color.black
                    }
                }
                .clipped()

            if isInkTruncated {
                Button {
                    isInkFullscreenPresented = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 28)
                        .foregroundColor(.white)
                        .background(excerpt.category.themeColor.opacity(0.9))
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.14), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                .padding(.bottom, AppSpacing.l)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Text(excerpt.category.displayName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(excerpt.category.themeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(excerpt.category.themeColor.opacity(0.15))
                .clipShape(Capsule())
                .padding([.top, .trailing], 16)
        }
        .onPreferenceChange(MobileInkExcerptHeightPreferenceKey.self) { height in
            if abs(naturalInkHeight - height) > 1 {
                naturalInkHeight = height
            }
        }
        .readingRecordCardStyle()
    }

    @ViewBuilder
    private var inkTextLayout: some View {
        VStack(alignment: .center, spacing: 0) {
            if [.poetry, .lyric, .prose].contains(excerpt.category) {
                inkTitleAndAuthor
            }

            switch excerpt.category {
            case .poetry:
                Text(excerpt.content)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .lineSpacing(14)
                    .foregroundColor(.primary.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            case .lyric, .prose:
                Text(indentedContent)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .lineSpacing(14)
                    .foregroundColor(.primary.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .quote:
                Text(excerpt.content)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .lineSpacing(14)
                    .foregroundColor(.primary.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 24)
                HStack {
                    Spacer()
                    Text("—— \(excerpt.sourceAuthorDisplay)")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundColor(.secondary)
                }
            case .movie:
                Text(excerpt.content)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .lineSpacing(14)
                    .foregroundColor(.primary.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 24)
                HStack {
                    Spacer()
                    Text("—— \(excerpt.sourceAuthorDisplay)（\(excerpt.sourceTitleDisplay)）")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundColor(.secondary)
                }
            case .web:
                Text(excerpt.content)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .lineSpacing(14)
                    .foregroundColor(.primary.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .bookExcerpt, .note:
                Text(excerpt.content)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .lineSpacing(14)
                    .foregroundColor(.primary.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 24)
                if excerpt.isBookBound {
                    HStack {
                        Spacer()
                        Text("《\(excerpt.bookDisplayTitle)》")
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var inkTitleAndAuthor: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Spacer()
            Text(excerpt.sourceTitleDisplay)
                .font(.system(size: 28, weight: .heavy, design: .serif))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            Text("")
                .frame(width: 0)
                .overlay(alignment: .bottomLeading) {
                    if excerpt.sourceAuthorDisplay != "佚名" {
                        Text(excerpt.sourceAuthorDisplay)
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(.secondary)
                            .fixedSize()
                            .offset(x: 20, y: -2)
                    }
                }
            Spacer()
        }
        .padding(.bottom, 20)
    }

    private var indentedContent: String {
        excerpt.content
            .components(separatedBy: .newlines)
            .map { "\u{3000}\u{3000}" + $0 }
            .joined(separator: "\n")
    }

}

private struct MobileInkExcerptFullscreenView: View {
    let excerpt: ExcerptListItem
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var indentedContent: String {
        excerpt.content
            .components(separatedBy: .newlines)
            .map { "\u{3000}\u{3000}" + $0 }
            .joined(separator: "\n")
    }

    private var supportingSource: String? {
        guard let source = excerpt.source?.trimmingCharacters(in: .whitespacesAndNewlines), !source.isEmpty else {
            return nil
        }
        guard source != excerpt.sourceTitleDisplay else {
            return nil
        }
        return source
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppColors.primaryBackground(for: colorScheme)
                .ignoresSafeArea()
            Rectangle()
                .fill(AppMaterials.modal)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 36) {
                    header
                    content
                    attribution
                    sourceNote
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, 120)
                .frame(maxWidth: .infinity)
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, AppSpacing.xl)
            .padding(.trailing, AppSpacing.l)
        }
        .background(
            Button("") { onClose() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
        )
    }

    @ViewBuilder
    private var header: some View {
        if [.poetry, .lyric, .prose].contains(excerpt.category) {
            VStack(spacing: 14) {
                Text(excerpt.sourceTitleDisplay)
                    .font(.system(size: 32, weight: .heavy, design: .serif))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                if excerpt.sourceAuthorDisplay != "佚名" {
                    Text(excerpt.sourceAuthorDisplay)
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 96)
        } else {
            Spacer().frame(height: 76)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch excerpt.category {
        case .poetry:
            Text(excerpt.content)
                .font(.system(size: 20, weight: .regular, design: .serif))
                .lineSpacing(18)
                .foregroundColor(.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        case .lyric, .prose:
            Text(indentedContent)
                .font(.system(size: 20, weight: .regular, design: .serif))
                .lineSpacing(18)
                .foregroundColor(.primary.opacity(0.9))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .quote, .movie, .web, .bookExcerpt, .note:
            Text(excerpt.content)
                .font(.system(size: 20, weight: .regular, design: .serif))
                .lineSpacing(18)
                .foregroundColor(.primary.opacity(0.9))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var attribution: some View {
        if excerpt.category == .quote {
            HStack {
                Spacer()
                Text("—— \(excerpt.sourceAuthorDisplay)")
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
        } else if excerpt.category == .movie {
            HStack {
                Spacer()
                Text("—— \(excerpt.sourceAuthorDisplay)（\(excerpt.sourceTitleDisplay)）")
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
        } else if [.bookExcerpt, .note].contains(excerpt.category), excerpt.isBookBound {
            HStack {
                Spacer()
                Text("《\(excerpt.bookDisplayTitle)》")
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
        }
    }

    @ViewBuilder
    private var sourceNote: some View {
        if let supportingSource {
            VStack(alignment: .leading, spacing: 16) {
                Divider()
                Text("来源 / 注释")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                Text(supportingSource)
                    .font(.system(size: 15, design: .serif))
                    .lineSpacing(10)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 54)
        }
    }
}


#if DEBUG
#Preview("灵感墙") {
    PreviewWithData {
        MobileInspirationWallView()
    }
}
#endif


#endif
