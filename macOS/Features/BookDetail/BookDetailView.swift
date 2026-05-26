#if os(macOS)
import SwiftData
import SwiftUI

// MARK: - ✨ 书籍详情主容器

/// macOS 端专属的书籍全景详情页。
struct BookDetailView: View {
    let book: Book
    @Binding var selectedBook: Book?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    // ✨ 状态上提：外层控制编辑和删除的弹出
    @Binding var showEditSheet: Bool
    @Binding var showDeleteAlert: Bool
    
    @State private var showAddExcerptSheet = false
    @State private var isDeleteMode = false
    
    var body: some View {
        ZStack(alignment: .top) {
            AppColors.primaryBackground(for: colorScheme)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedBook = nil
                }
            
            // ================= 2. 全局无界内容区 =================
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    BookDetailSections(
                        book: book,
                        isDeleteMode: $isDeleteMode,
                        onDeleteExcerpt: { deleteRecord($0) }
                    )
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 100)
                .padding(.top, 100)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // ================= 3. 弹窗引擎池 =================
            .sheet(isPresented: $showAddExcerptSheet) {
                ContentEditorSheet(isPresented: $showAddExcerptSheet, book: book, mode: .excerpt)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            BookEditorSheet(isPresented: $showEditSheet, bookToEdit: book)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    selectedBook = nil
                } label: {
                    toolbarIcon("chevron.backward")
                }
                .help("返回")
                .keyboardShortcut("[", modifiers: .command)
            }

            ToolbarItem { Spacer() }

            ToolbarItem {
                ControlGroup {
                    Button {
                        showEditSheet = true
                    } label: {
                        toolbarIcon("square.and.pencil")
                    }
                    .help("编辑书籍")
                    .keyboardShortcut("e", modifiers: .command)

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        toolbarIcon("trash")
                    }
                    .help("删除书籍")
                    .keyboardShortcut(.delete, modifiers: [])
                }
            }

            ToolbarItem {
                ControlGroup {
                    Button {
                        showAddExcerptSheet = true
                    } label: {
                        toolbarIcon("text.quote")
                    }
                    .help("添加摘录")

                    Button {
                        withAnimation(.appContentFade) {
                            isDeleteMode.toggle()
                        }
                    } label: {
                        toolbarIcon(isDeleteMode ? "checkmark.circle.fill" : "slider.horizontal.3")
                    }
                    .help("管理摘录")
                }
            }
        }
        .alert("删除书籍", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("确认删除", role: .destructive) {
                // 1. 立即清空选中状态（触发详情页关闭动画）
                selectedBook = nil
                
                // 2. 延迟执行删除（等待关闭动画完成），并强制同步
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    do {
                        try ReadingDataService.shared.deleteBookAndSave(book, context: modelContext)
                        print("✅ 书籍及物理文件已彻底销毁")
                    } catch {
                        print("❌ 删除保存失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func toolbarIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
    }
    
    // MARK: - 记录销毁逻辑 (✨ 升级为单一模型 Excerpt)
    
    private func deleteRecord(_ item: Excerpt) {
        withAnimation(.appContentFade) {
            try? ReadingDataService.shared.deleteExcerpt(item, context: modelContext)
        }
        
        // 统计这本树下所有的批注数量（合并后的表）
        let totalCount = book.excerpts?.count ?? 0
        if totalCount <= 1 {
            withAnimation(.appContentFade) { isDeleteMode = false }
        }
    }
}

// MARK: - ✨ 预览装配

struct BookDetailPreviewWrapper: View {
    @Query var books: [Book]
    @State private var selectedBook: Book?
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        if let book = books.first {
            BookDetailView(
                book: book,
                selectedBook: $selectedBook,
                showEditSheet: $showEditSheet,
                showDeleteAlert: $showDeleteAlert
            )
            .frame(width: 1000, height: 800)
            .onAppear { selectedBook = book }
        } else {
            Text("加载假数据中...")
        }
    }
}
#endif
