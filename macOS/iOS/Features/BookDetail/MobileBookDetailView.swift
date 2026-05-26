#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 📚 主详情页容器

/// iOS 端专属的书籍全景详情页。
///
/// **架构职责：**
/// 1. 统筹整个页面的纵向滚动布局与底层色彩。
/// 2. 集中管理所有的 Sheet 弹窗以及危险操作警告。
/// 3. 为内部的所有子组件下发 `book` 实体与当前的 `isDeleteMode` 删除锁定状态。
struct MobileBookDetailView: View {
    let book: Book
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // 弹窗与控制状态
    @State private var showDeleteAlert = false
    @State private var showAddExcerptSheet = false
    @State private var showEditSheet = false
    @State private var showMaxPlannedAlert = false
    
    @State private var isDeleteMode = false
    
    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: AppSpacing.l) {
                    MobileBookIdentityHeader(book: book)
                        .padding(.bottom, AppSpacing.xs)

                    MobileReadingStatusCard(book: book, showMaxAlert: $showMaxPlannedAlert)
                    MobileReadingDateCard(book: book)
                    MobileBookRatingCard(book: book)
                    MobileBookDetailLowerSections(
                        book: book,
                        isDeleteMode: $isDeleteMode,
                        onDelete: { itemToDelete in
                            deleteRecord(itemToDelete)
                        }
                    )
                    .equatable()
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppSpacing.emptyState)
            }
        }
        .background(AppColors.primaryBackground(for: colorScheme))
        .navigationBarTitleDisplayMode(.inline)
        // ================= 弹窗路由引擎 =================
        .alert("删除书籍", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("确认删除", role: .destructive) {
                try? ReadingDataService.shared.deleteBookAndSave(book, context: modelContext)
                dismiss() // 返回上一级画廊
            }
        } message: { Text("确定要删除《\(book.title)》吗？相关的读书笔记也会一并清除。") }
        .alert("席位已满", isPresented: $showMaxPlannedAlert) {
            Button("知道啦", role: .cancel) {}
        } message: { Text("主页“想读焦点”最多同时放置 4 本书。请先取消其他的想读状态吧！") }
        .sheet(isPresented: $showAddExcerptSheet) { MobileAddExcerptSheet(book: book) }
        .sheet(isPresented: $showEditSheet) { MobileBookEditorSheet(bookToEdit: book) }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { showEditSheet = true }) {
                    Image(systemName: "square.and.pencil")
                }
                Button(role: .destructive, action: { showDeleteAlert = true }) {
                    Image(systemName: "trash")
                }
                Button(action: { showAddExcerptSheet = true }) {
                    Image(systemName: "text.quote")
                }
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isDeleteMode.toggle()
                    }
                }) {
                    Image(systemName: isDeleteMode ? "checkmark.circle.fill" : "slider.horizontal.3")
                }
            }
        }
    }
    
    // MARK: - 内部业务控制
    
    /// 执行摘录与笔记物理销毁。
    /// ✨ 修复：适配单表大一统，直接接收 Excerpt 进行操作
    private func deleteRecord(_ item: Excerpt) {
        withAnimation(.easeInOut(duration: 0.18)) {
            try? ReadingDataService.shared.deleteExcerpt(item, context: modelContext)
        }
        
        let count = book.excerpts?.count ?? 0
        // 若删完最后一条，自动切回普通模式
        if count <= 1 {
            withAnimation(.easeInOut(duration: 0.18)) { isDeleteMode = false }
        }
    }
}

private struct MobileBookDetailLowerSections: View, Equatable {
    let book: Book
    @Binding var isDeleteMode: Bool
    let onDelete: (Excerpt) -> Void

    private var tagsVersion: String {
        book.tags.joined(separator: "\u{1f}")
    }

    private var sessionsVersion: String {
        let sessions = book.sessions ?? []
        let newestStart = sessions.map(\.startedAt).max()?.timeIntervalSinceReferenceDate ?? 0
        let newestEnd = sessions.map(\.endedAt).max()?.timeIntervalSinceReferenceDate ?? 0
        let totalDuration = sessions.reduce(0) { $0 + max($1.duration, 0) }
        return "\(sessions.count)-\(newestStart)-\(newestEnd)-\(totalDuration)"
    }

    private var excerptsVersion: String {
        let excerpts = book.excerpts ?? []
        let newest = excerpts.map(\.createdAt).max()?.timeIntervalSinceReferenceDate ?? 0
        let contentLength = excerpts.reduce(0) { $0 + $1.content.count }
        return "\(excerpts.count)-\(newest)-\(contentLength)"
    }

    static func == (lhs: MobileBookDetailLowerSections, rhs: MobileBookDetailLowerSections) -> Bool {
        lhs.book.id == rhs.book.id
            && lhs.isDeleteMode == rhs.isDeleteMode
            && lhs.tagsVersion == rhs.tagsVersion
            && lhs.sessionsVersion == rhs.sessionsVersion
            && lhs.excerptsVersion == rhs.excerptsVersion
    }

    var body: some View {
        MobileBookTagsCard(book: book)
        MobileReadingSessionCard(book: book)
        MobileBookExcerptsCard(book: book, isDeleteMode: $isDeleteMode, onDelete: onDelete)
    }
}

#if DEBUG
private struct PreviewMobileBookDetail: View {
    var body: some View {
        PreviewWithBook(title: "三体", author: "刘慈欣", currentAmount: 156) { book in
            MobileBookDetailView(book: book)
        }
        .modelContainer(previewModelContainer)
    }
}

#Preview("书籍详情页") {
    PreviewMobileBookDetail()
}
#endif


#endif
