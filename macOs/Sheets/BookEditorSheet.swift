#if os(macOS)
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - ✨ 编辑与添置弹窗 (Apple 原生规范重构版)

/// 涵盖“新增图书”与“编辑旧书信息”双重职责的表单弹窗。
///
/// **功能与交互：**
/// 该弹窗严格遵循 macOS 原生的系统表单规范，将视觉重心置于图片区域。
/// - **智能判别**：根据传入的 `bookToEdit` 是否为 nil，动态决定标题与确认按钮的文字。
/// - **原生拖拽**：封面区域通过注入 `onDrop` 和 `fileImporter` 支持本地文件的直接拖拽及弹窗选取。
/// - **防呆机制**：拥有书名查重能力，避免同名书籍的二次录入；并在必填项未填充时，原生置灰（禁用）保存按钮。
struct BookEditorSheet: View {
    @Query var allBooks: [Book]
    @Environment(\.modelContext) private var modelContext
    
    @Binding var isPresented: Bool
    
    /// 要编辑的书籍实体。若为 `nil`，则本组件代表处于“新建”模式。
    var bookToEdit: Book? = nil
    
    @State private var titleInput: String = ""
    @State private var authorInput: String = ""
    @State private var selectedCoverData: Data? = nil
    @State private var isShowingImagePicker = false
    @State private var showDuplicateAlert = false
    
    var body: some View {
        let isEdit = bookToEdit != nil
        
        VStack(spacing: 0) {
            // ================= 1. 原生顶部 Header =================
            HStack(spacing: 10) {
                Image(systemName: isEdit ? "book.closed.fill" : "plus.square.dashed")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                
                Text(isEdit ? "编辑档案" : "添置新书")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            Divider()
            
            // ================= 2. 居中核心内容区 (封面 + 表单) =================
            VStack(spacing: 28) {
                
                // ⬆️ 顶部：封面选择区 (视觉重心)
                Button(action: { isShowingImagePicker = true }) {
                    if let data = selectedCoverData {
                        LocalCoverView(coverData: data, fallbackTitle: titleInput.isEmpty ? "暂无书名" : titleInput)
                            .frame(width: 140, height: 210)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(color: Color.black.opacity(0.2), radius: 6, y: 3)
                            // 增加一个微弱的边框让深色封面在暗黑模式下也能区分边界
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    } else {
                        // 优雅的空状态占位
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                                .background(Color.secondary.opacity(0.03))
                            
                            VStack(spacing: 12) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundColor(.blue.opacity(0.8))
                                
                                Text("设置封面")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text("支持拖拽移入 · 比例 2:3")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 140, height: 210)
                    }
                }
                .buttonStyle(.plain)
                .fileImporter(isPresented: $isShowingImagePicker, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
                    do {
                        guard let selectedFile: URL = try result.get().first else { return }
                        if selectedFile.startAccessingSecurityScopedResource() {
                            defer { selectedFile.stopAccessingSecurityScopedResource() }
                            selectedCoverData = try Data(contentsOf: selectedFile)
                        }
                    } catch { /* 静默处理 */ }
                }
                // 启用图片类型的拖放支持
                .onDrop(of: [UTType.image], isTargeted: nil) { providers in
                    if let provider = providers.first {
                        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                            if let data = data { DispatchQueue.main.async { self.selectedCoverData = data } }
                        }
                        return true
                    }
                    return false
                }
                
                // ⬇️ 底部：信息输入区 (限制宽度，保持整体紧凑协调)
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Text("书名").foregroundColor(.secondary).frame(width: 32, alignment: .trailing)
                        TextField("例如：百年孤独", text: $titleInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14))
                    }
                    
                    HStack(spacing: 12) {
                        Text("作者").foregroundColor(.secondary).frame(width: 32, alignment: .trailing)
                        TextField("例如：加西亚·马尔克斯", text: $authorInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14))
                    }
                }
                .frame(width: 260) // 限制宽度，与封面的尺寸形成舒适的梯形视觉
            }
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
            // 微微不同的底色，突出表单区域
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // ================= 3. 原生底部 Footer =================
            HStack {
                Spacer()
                
                // 🍏 macOS 标准的取消和确认按钮配置
                Button("取消") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                
                let isFormEmpty = titleInput.trimmingCharacters(in: .whitespaces).isEmpty || authorInput.trimmingCharacters(in: .whitespaces).isEmpty
                let hasChanges = bookToEdit == nil ? true : (titleInput != bookToEdit?.title || authorInput != bookToEdit?.author || selectedCoverData != bookToEdit?.coverData)
                
                Button(isEdit ? "保存修改" : "确认录入") { saveBook() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    // 防呆机制：当没有内容输入，或者编辑状态下内容无变化时，禁止保存
                    .disabled(isFormEmpty || !hasChanges)
            }
            .padding(16)
        }
        .frame(width: 420) // 整体窗口宽度收紧，更显精致
        .onAppear {
            if let book = bookToEdit {
                titleInput = book.title ?? ""
                authorInput = book.author ?? ""
                selectedCoverData = book.coverData
            }
        }
        .alert("书名重复", isPresented: $showDuplicateAlert) {
            Button("好的", role: .cancel) { }
        } message: {
            Text("您当前添加的书籍已存在，请检查书库。")
        }
    }
    
    // MARK: - 存储逻辑
    
    /// 执行表单数据的提取与覆盖。
    ///
    /// 如果是新建模式，内部会自动执行基于书名的强排重校验；
    /// 如果是通过了排重，会实例化 `Book` 插入环境；若是编辑模式，则对旧实例字段执行覆写操作。
    private func saveBook() {
        guard !titleInput.isEmpty, !authorInput.isEmpty else { return }
        let existingTitles = Set(allBooks.compactMap { $0.title })
        
        if let book = bookToEdit {
            book.title = titleInput; book.author = authorInput; book.coverData = selectedCoverData
        } else {
            if existingTitles.contains(titleInput) {
                self.showDuplicateAlert = true; return
            } else {
                let newBook = Book(title: titleInput, author: authorInput)
                newBook.coverData = selectedCoverData
                modelContext.insert(newBook)
            }
        }
        try? modelContext.save()
        isPresented = false
    }
}
#endif
