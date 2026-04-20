#if os(macOS)
import SwiftUI
import SwiftData
import AppKit

// MARK: - ✨ 书籍详情主容器

/// macOS 端专属的书籍全景详情页。
///
/// **架构职责：**
/// 作为详情页的根视图 (Root View)，它不负责具体的业务 UI 渲染，而是专注于：
/// 1. **全屏转场与背景**：提供带有打断手势（点击空白处退出）的纯净毛玻璃遮罩。
/// 2. **路由与弹窗枢纽**：集中管理所有的 Sheet 弹窗（添加摘录、添加笔记、编辑书籍信息）以及危险操作警告（删除书籍）。
/// 3. **上下文注入**：将全局的 `modelContext` 环境向下分发，并持有状态栏的全局数据变更。
struct BookDetailView: View {
    /// 当前正在查看的书籍实体。
    let book: Book
    /// 承接外层画廊的共享动画标识符。
    let namespace: Namespace.ID
    
    /// 绑定的触发动画的封面 ID。
    @Binding var activeCoverID: String
    /// 绑定的选书状态。置为 `nil` 即可触发优雅的退出动画。
    @Binding var selectedBook: Book?
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - 弹窗与交互状态
    
    @State private var showAddExcerptSheet = false
    @State private var showAddNoteSheet = false
    @State private var isDeleteMode = false
    
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        ZStack {
            // ================= 1. 纯净毛玻璃背景 =================
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()
            
            // 细微的系统遮罩层，增加立体感 (替代手动的 isDark 判断)
            Color(nsColor: .windowBackgroundColor).opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // 点击空白处返回，享受右滑出退场动画
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { selectedBook = nil }
                }
            
            // ================= 2. 全局无界内容区 =================
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 80) {
                    // 👆 上大模块：重构后的优雅书籍看板
                    BookDossierView(book: book)
                        .zIndex(1)
                                                                                                                                                                        
                    // 👇 下大模块：摘要和笔记
                    VStack(spacing: 30) {
                        // 标题与控制按钮
                        VStack(spacing: 16) {
                            HStack(alignment: .center) {
                                Text("思考的痕迹")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                HStack(spacing: 12) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isDeleteMode.toggle() }
                                    }) {
                                        Label(isDeleteMode ? "完成" : "管理", systemImage: isDeleteMode ? "checkmark" : "trash")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(isDeleteMode ? .blue : .gray)
                                    .controlSize(.large)
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showAddNoteSheet = true }
                                    }) {
                                        Label("笔记", systemImage: "square.and.pencil")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.purple)
                                    .controlSize(.large)
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showAddExcerptSheet = true }
                                    }) {
                                        Label("摘录", systemImage: "quote.opening")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.indigo)
                                    .controlSize(.large)
                                }
                            }
                            Divider()
                        }
                            
                        BookExcerptsView(
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
            }
            .ignoresSafeArea(edges: .top)
            
            // ================= 3. 弹窗引擎池 =================
            .sheet(isPresented: $showAddExcerptSheet) {
                AddContentSheet(isPresented: $showAddExcerptSheet, book: book, mode: .excerpt)
            }
            .sheet(isPresented: $showAddNoteSheet) {
                AddContentSheet(isPresented: $showAddNoteSheet, book: book, mode: .note)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showEditSheet = true } }) {
                    Image(systemName: "pencil")
                }
                .help("编辑书籍信息")
                
                Button(action: { showDeleteAlert = true }) {
                    Image(systemName: "trash").foregroundStyle(Color.red)
                }
                .help("彻底删除书籍")
            }
        }
        .sheet(isPresented: $showEditSheet) { BookEditorSheet(isPresented: $showEditSheet, bookToEdit: book) }
        .alert("删除书籍", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("确认删除", role: .destructive) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { selectedBook = nil }
                // 延迟一点执行删除，让返回动画播完
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { modelContext.delete(book) }
            }
        } message: {
            Text("确定要删除《\(book.title ?? "未知")》吗？相关的读书笔记也会一并清除。")
        }
    }
    
    /// 执行物理销毁记录操作。
    ///
    /// - Parameter item: 包装了 `Excerpt` 或 `Note` 的抽象枚举项。
    private func deleteRecord(_ item: RecordItem) {
        withAnimation(.spring()) {
            switch item {
            case .excerpt(let excerpt): modelContext.delete(excerpt)
            case .note(let note): modelContext.delete(note)
            }
        }
        let excerptCount = book.excerpts?.count ?? 0
        let noteCount = book.notes?.count ?? 0
        if (excerptCount + noteCount) <= 1 {
            withAnimation { isDeleteMode = false }
        }
    }
}
#endif
