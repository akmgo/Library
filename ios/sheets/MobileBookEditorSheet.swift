import SwiftUI
import SwiftData
import PhotosUI

#if os(iOS)
struct MobileBookEditorSheet: View {
    // 传入 book 代表编辑模式，传入 nil 代表新增模式
    var bookToEdit: Book? = nil
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @Query var allBooks: [Book]
    
    // 表单状态
    @State private var title: String
    @State private var author: String
    @State private var coverData: Data? = nil
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showDuplicateAlert = false
    
    // 初始化时灌入现有数据（如果是编辑模式）
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
                                // 🍏 原生极简的空占位符，放弃虚线框
                                Label("轻点选择封面", systemImage: "photo.badge.plus")
                                    .foregroundColor(.accentColor)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 12)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // 如果有封面，提供一个移除封面的快捷选项
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
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            // 监听相册选择器的变化，异步加载新图片数据
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
    
    private func saveChanges() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        let cleanAuthor = author.trimmingCharacters(in: .whitespaces)
        guard !cleanTitle.isEmpty else { return }
        
        let existingTitles = Set(allBooks.compactMap { $0.title })
        
        if let book = bookToEdit {
            // 编辑模式
            book.title = cleanTitle
            book.author = cleanAuthor
            book.coverData = coverData
        } else {
            // 新增模式
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
