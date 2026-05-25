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
    @Namespace private var animationNamespace
    
    var body: some View {
        ZStack {
            // ================= 1. 全局无界内容区 =================
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppSpacing.xxl) {
                    
                    // ================= 👆 上半部分：书籍详情大模块 =================
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        
                        // --- 上：左右分栏 (左封面，右信息) ---
                        HStack(alignment: .top, spacing: AppSpacing.m) {
                            // 左侧：封面 (✨ 补齐了 coverID 缓存钩子)
                            BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                                .frame(width: 120, height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
                                .shadow(color: Color.black.opacity(0.15), radius: 12, y: 6)
                            
                            // 右侧：紧凑型档案信息
                            VStack(alignment: .leading, spacing: 0) {
                                // 书名、作者与想读按钮
                                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                    HStack(alignment: .top) {
                                        Text(book.title)
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                        Spacer(minLength: 4)
                                        
                                        // ✨ “想读”本质上是一种特殊的 unread 状态，这里包容它
                                        if book.status == .unread || book.status == .planned {
                                            MobilePlannedStatusToggle(book: book, showMaxAlert: $showMaxPlannedAlert)
                                                .offset(y: -4)
                                        }
                                    }
                                    Text(book.author)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                // 状态切换器
                                MobileCompactStatusPicker(book: book, animationNamespace: animationNamespace)
                                
                                Spacer()
                                
                                // 阅读日期与历时
                                MobileCompactDatePickers(book: book)
                                
                                Spacer()
                                
                                // 个人评价
                                MobileCompactRatingView(book: book)
                            }
                            .frame(height: 180)
                        }
                        
                        Divider()
                        // --- 下：多列自适应标签组件 ---
                        MobileCompactTagsView(book: book)
                    }
                    .padding(AppSpacing.l)
                    .background(AppColors.secondaryBackground(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
                    .padding(.horizontal, AppSpacing.m)
                    .padding(.top, AppSpacing.m)

                    // ================= 阅读记录 =================
                    MobileReadingSessionCard(book: book)

                    // ================= 👇 下半部分：摘录与笔记展示区 =================
                    VStack(spacing: AppSpacing.l) {
                        // 区域头部栏
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text("思考的痕迹")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("留住阅读时的金句与灵感")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: AppSpacing.xs) {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isDeleteMode.toggle() }
                                }) {
                                    Text(isDeleteMode ? "完成" : "管理")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(isDeleteMode ? .white : .primary)
                                        .padding(.horizontal, AppSpacing.s).padding(.vertical, 6)
                                        .background(isDeleteMode ? Color.red : Color.secondary.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                                
                                Button(action: { showAddExcerptSheet = true }) {
                                    HStack(spacing: AppSpacing.xxs) {
                                        Image(systemName: "quote.opening").font(.system(size: 10))
                                        Text("记摘录").font(.system(size: 12, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, AppSpacing.s).padding(.vertical, 6)
                                    .background(Color.indigo)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.l)
                        
                        // 混合时间线列表渲染
                        MobileExcerptsAndNotesList(book: book, isDeleteMode: isDeleteMode) { itemToDelete in
                            deleteRecord(itemToDelete)
                        }
                    }
                }
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showEditSheet = true }) {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
    }
    
    // MARK: - 内部业务控制
    
    /// 执行摘录与笔记物理销毁。
    /// ✨ 修复：适配单表大一统，直接接收 Excerpt 进行操作
    private func deleteRecord(_ item: Excerpt) {
        withAnimation(.spring()) {
            try? ReadingDataService.shared.deleteExcerpt(item, context: modelContext)
        }
        
        let count = book.excerpts?.count ?? 0
        // 若删完最后一条，自动切回普通模式
        if count <= 1 {
            withAnimation { isDeleteMode = false }
        }
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
