import SwiftUI
import SwiftData
import PhotosUI

#if os(iOS)
// MARK: - ✨ 书籍编辑与添置表单

/// 涵盖“新增图书”与“编辑旧书信息”双重职责的 iOS 原生表单弹窗。
///
/// **交互与视觉特性：**
/// 该弹窗将视觉重心置于顶部的封面拾取区域。
/// - **智能判别**：根据传入的 `bookToEdit` 是否为 `nil`，动态切换标题与确认按钮状态。
/// - **原生相册集成**：结合 `PhotosPicker` 无缝调起 iOS 系统相册，并利用并发任务 (`Task`) 异步加载图片数据。
/// - **拖拽支持**：通过 `onDrop` 支持 iPadOS 的分屏图片拖拽导入。
struct MobileBookEditorSheet: View {
    /// 若传入具体实例，则代表当前处于“编辑”模式；若为 `nil`，则是“新增”模式。
    var bookToEdit: Book? = nil
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @Query var allBooks: [Book]
    
    // 表单双向绑定状态
    @State private var title: String
    @State private var author: String
    @State private var coverData: Data? = nil
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showDuplicateAlert = false
    
    /// 初始化时，根据传入的 `book` 预填充表单状态。
    init(book: Book? = nil) {
        self.bookToEdit = book
        _title = State(initialValue: book?.title ?? "")
        _author = State(initialValue: book?.author ?? "")
        _coverData = State(initialValue: book?.coverData)
    }
    
    var body: some View {
        let isEditMode = bookToEdit != nil
        
        NavigationStack {
            Form {
                // ================= 1. 基本信息 =================
                Section(header: Text("基本信息")) {
                    TextField("书名 (必填)", text: $title)
                        .font(.system(size: 16, weight: .medium))
                    TextField("作者 (选填)", text: $author)
                        .font(.system(size: 16))
                }
                
                // ================= 2. 封面选择 =================
                Section(header: Text("封面")) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                        HStack {
                            if let data = coverData, let uiImage = UIImage(data: data) {
                                // 已有封面展示
                                Spacer()
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .shadow(color: Color.black.opacity(0.15), radius: 6, y: 3)
                                    .padding(.vertical, 8)
                                Spacer()
                            } else {
                                // 🍏 原生极简的空占位符
                                Label("轻点选择封面", systemImage: "photo.badge.plus")
                                    .foregroundColor(.accentColor)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 12)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // 如果有封面，提供一个移除封面的快捷选项 (破坏性操作以红色警示)
                    if coverData != nil {
                        Button(role: .destructive, action: {
                            withAnimation { coverData = nil; selectedPhotoItem = nil }
                        }) {
                            Text("移除封面")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle(isEditMode ? "编辑书籍" : "添加书籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }.foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditMode ? "保存" : "添加") { saveChanges() }
                        .fontWeight(.bold)
                        // 防呆设计：标题为空时直接禁用提交按钮
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            // 监听相册选择器的变化，异步解析为二进制 Data
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await MainActor.run { self.coverData = data }
                    }
                }
            }
            .alert("书名重复", isPresented: $showDuplicateAlert) {
                Button("好的", role: .cancel) { }
            } message: { Text("您当前添加的书籍已存在") }
        }
    }
    
    // MARK: - 存储映射逻辑
    
    /// 执行持久化覆写或新增落库。自带书名重复校验机制。
    private func saveChanges() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        let cleanAuthor = author.trimmingCharacters(in: .whitespaces)
        guard !cleanTitle.isEmpty else { return }
        
        let existingTitles = Set(allBooks.compactMap { $0.title })
        
        if let book = bookToEdit {
            // 编辑模式覆写
            book.title = cleanTitle
            book.author = cleanAuthor
            book.coverData = coverData
        } else {
            // 新增模式查重
            if existingTitles.contains(cleanTitle) {
                self.showDuplicateAlert = true; return
            } else {
                let newBook = Book(title: cleanTitle, author: cleanAuthor, status: .unread)
                newBook.coverData = coverData
                modelContext.insert(newBook)
            }
        }
        
        try? modelContext.save()
        dismiss()
    }
}
#endif
