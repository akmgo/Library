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
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { selectedBook = nil }
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
                                
                                HStack(spacing: 12) {
                                    ProminentActionButton(
                                        title: isDeleteMode ? "完成" : "管理",
                                        systemImage: isDeleteMode ? "checkmark" : "trash",
                                        tintColor: isDeleteMode ? .blue : .gray,
                                        action: { withAnimation(.spring()) { isDeleteMode.toggle() } }
                                    )
                                    .glassEffect(isDeleteMode ? .regular.tint(.blue).interactive() : .regular.interactive(), in: .capsule)
                                    
                                    ProminentActionButton(
                                        title: "笔记",
                                        systemImage: "square.and.pencil",
                                        tintColor: .purple,
                                        action: { showAddNoteSheet = true }
                                    )
                                    .glassEffect(.regular.tint(.purple).interactive(), in: .capsule)
                                    
                                    ProminentActionButton(
                                        title: "摘录",
                                        systemImage: "quote.opening",
                                        tintColor: .indigo,
                                        action: { showAddExcerptSheet = true }
                                    )
                                    .glassEffect(.regular.tint(.indigo).interactive(), in: .capsule)
                                }
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
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    selectedBook = nil
                }
                
                // 2. 延迟执行删除（等待关闭动画完成），并强制同步
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // ✨ 核心操作：调用 LocalBookManager 进行物理超度
                    LocalBookManager.shared.deleteBook(book, context: modelContext)
                            
                    do {
                        // ✨ 核心操作：强制持久化到磁盘，确保画廊读取的是最新状态
                        try modelContext.save()
                                
                        print("✅ 书籍及物理文件已彻底销毁")
                    } catch {
                        print("❌ 删除保存失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - 记录销毁逻辑 (✨ 升级为单一模型 BookAnnotation)
    
    private func deleteRecord(_ item: BookAnnotation) {
        withAnimation(.spring()) {
            // 直接删除该实体，无需再走 switch 缝合逻辑
            modelContext.delete(item)
        }
        
        // 统计这本树下所有的批注数量（合并后的表）
        let totalCount = book.annotations?.count ?? 0
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
