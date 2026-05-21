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
    @State private var showAddNoteSheet = false
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
                VStack(spacing: 80) {
                    // 👆 上大模块
                    BookDossier(book: book)
                        .zIndex(1)
                    
                    // 👇 下大模块
                    VStack(spacing: 30) {
                        VStack(spacing: 16) {
                            HStack(alignment: .center) {
                                Text("思考的痕迹")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            Divider()
                        }
                        
                        BookExcerpts(
                            book: book,
                            isDeleteMode: isDeleteMode,
                            onDelete: { itemToDelete in deleteRecord(itemToDelete) }
                        )
                    }
                    .frame(maxWidth: .infinity)
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
            .sheet(isPresented: $showAddNoteSheet) {
                ContentEditorSheet(isPresented: $showAddNoteSheet, book: book, mode: .note)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            BookEditorSheet(isPresented: $showEditSheet, bookToEdit: book)
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
    
    // MARK: - 记录销毁逻辑 (✨ 升级为单一模型 Excerpt)
    
    private func deleteRecord(_ item: Excerpt) {
        withAnimation(.spring()) {
            try? ReadingDataService.shared.deleteExcerpt(item, context: modelContext)
        }
        
        // 统计这本树下所有的批注数量（合并后的表）
        let totalCount = book.excerpts?.count ?? 0
        if totalCount <= 1 {
            withAnimation { isDeleteMode = false }
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
