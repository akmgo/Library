#if os(macOS)
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - ✨ 编辑与添置弹窗 (完整版)

struct BookEditorSheet: View {
    @Query var allBooks: [Book]
    @Environment(\.modelContext) private var modelContext
    
    @Binding var isPresented: Bool
    
    var bookToEdit: Book? = nil
    
    @State private var titleInput: String = ""
    @State private var authorInput: String = ""
    @State private var selectedCoverData: Data? = nil
    @State private var isShowingImagePicker = false
    @State private var showDuplicateAlert = false
    
    // 云端局部搜索状态
    @State private var isSearchingCloud = false
    @State private var showSearchResults = false
    @State private var searchResults: [BookSearchResult] = []
    @State private var searchError: String? = nil
    
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
            
            Divider().opacity(0.5)
            
            // ================= 2. 居中核心内容区 =================
            VStack(spacing: 28) {
                
                // ⬆️ 顶部：封面选择区
                Button(action: { isShowingImagePicker = true }) {
                    if let data = selectedCoverData, let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 210)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(color: Color.black.opacity(0.2), radius: 6, y: 3)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    } else {
                        ZStack {
                            Color.clear.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8.0))
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                            
                            VStack(spacing: 12) {
                                Image(systemName: "photo.badge.plus").font(.system(size: 32, weight: .light)).foregroundColor(.blue.opacity(0.8))
                                Text("设置封面").font(.system(size: 13, weight: .medium)).foregroundColor(.primary)
                                Text("支持拖拽移入 · 比例 2:3").font(.system(size: 11)).foregroundColor(.secondary)
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
                            let data = try Data(contentsOf: selectedFile)
                            DispatchQueue.main.async { self.selectedCoverData = data }
                        }
                    } catch { /* 静默处理 */ }
                }
                .onDrop(of: [UTType.image], isTargeted: nil) { providers in
                    if let provider = providers.first {
                        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                            if let data = data { DispatchQueue.main.async { self.selectedCoverData = data } }
                        }
                        return true
                    }
                    return false
                }
                
                // ⬇️ 底部：信息输入区
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Text("书名").foregroundColor(.secondary).frame(width: 32, alignment: .trailing)
                        
                        HStack(spacing: 8) {
                            TextField("例如：百年孤独", text: $titleInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                                .onSubmit { performInlineSearch() }
                                .onChange(of: titleInput) { _, newValue in
                                    if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                                        showSearchResults = false
                                    }
                                }
                            
                            Button(action: performInlineSearch) {
                                if isSearchingCloud {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(titleInput.isEmpty ? .secondary.opacity(0.4) : .blue.opacity(0.8))
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(titleInput.isEmpty || isSearchingCloud)
                            // ✨ 调用我们刚抽离出的公共气泡组件
                            .popover(isPresented: $showSearchResults, arrowEdge: .trailing) {
                                InlineSearchResultsPopover(
                                    results: searchResults,
                                    error: searchError,
                                    isLoading: isSearchingCloud,
                                    onSelect: applySearchResult
                                )
                            }
                        }
                        .padding(8)
                        .glassEffect(in: .rect(cornerRadius: 6))
                    }
                    
                    HStack(spacing: 12) {
                        Text("作者").foregroundColor(.secondary).frame(width: 32, alignment: .trailing)
                        TextField("例如：加西亚·马尔克斯", text: $authorInput)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .glassEffect(in: .rect(cornerRadius: 6))
                            .font(.system(size: 14))
                    }
                }
                .frame(width: 260)
            }
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
            
            Divider().opacity(0.5)
            
            // ================= 3. 底部 Footer =================
            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain).padding(.horizontal, 16).padding(.vertical, 6)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 6))
                
                let isFormEmpty = titleInput.trimmingCharacters(in: .whitespaces).isEmpty || authorInput.trimmingCharacters(in: .whitespaces).isEmpty
                let hasChanges = bookToEdit == nil ? true : (titleInput != bookToEdit?.title || authorInput != bookToEdit?.author || selectedCoverData != bookToEdit?.coverData)
                let canSave = !isFormEmpty && hasChanges
                
                Button(isEdit ? "保存修改" : "确认录入") { saveBook() }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .glassEffect(canSave ? .regular.tint(.blue).interactive() : .clear.interactive(), in: .rect(cornerRadius: 6))
                    .opacity(canSave ? 1.0 : 0.4)
            }
            .padding(16)
        }
        .frame(width: 420)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .background(WindowTransparentEffect())
        .onAppear {
            if let book = bookToEdit {
                titleInput = book.title; authorInput = book.author; selectedCoverData = book.coverData
            }
        }
        .alert("书名重复", isPresented: $showDuplicateAlert) {
            Button("好的", role: .cancel) { }
        } message: { Text("您当前添加的书籍已存在，请检查书库。") }
    }
    
    // MARK: - 行为与存储逻辑
    
    private func performInlineSearch() {
        guard !titleInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearchingCloud = true
        showSearchResults = true
        searchError = nil
        searchResults.removeAll()
        
        Task { @MainActor in
            do {
                let results = try await CloudSearchManager.shared.search(query: titleInput)
                if results.isEmpty {
                    searchError = "未能找到相关书籍，请检查书名是否准确"
                } else {
                    searchResults = results
                }
            } catch {
                searchError = "查询受阻：\(error.localizedDescription)"
            }
            isSearchingCloud = false
        }
    }
    
    // 一键填充气泡里的搜索结果
    private func applySearchResult(_ result: BookSearchResult, fetchedCoverData: Data?) {
        showSearchResults = false
        
        withAnimation(.snappy) {
            titleInput = result.title
            authorInput = result.author
            selectedCoverData = fetchedCoverData
        }
        
        if fetchedCoverData == nil {
            Task { @MainActor in
                if let coverData = await CloudSearchManager.shared.fetchCoverData(from: result.coverURL) {
                    withAnimation(.spring()) {
                        self.selectedCoverData = coverData
                    }
                }
            }
        }
    }
    
    // 核心保存逻辑
        private func saveBook() {
            guard !titleInput.isEmpty, !authorInput.isEmpty else { return }
            let existingTitles = Set(allBooks.compactMap { $0.title })
            
            if let book = bookToEdit {
                // ✨ 核心修复：检查封面是否发生了实质性变更
                let isCoverChanged = book.coverData != selectedCoverData
                
                // 编辑现有书籍：直接赋予新属性
                book.title = titleInput
                book.author = authorInput
                book.coverData = selectedCoverData
                
                // ✨ 核心修复：如果封面变了，必须强制踢掉内存中的旧缓存
                // 注意这里的 key 必须和 LocalCoverView 内部生成的 key 规则保持绝对一致！
                if isCoverChanged {
                    let cacheKey = "cover_img_\(book.id)"
                    ImageCacheManager.shared.removeImage(forKey: cacheKey)
                }
                
            } else {
                // 创建新书籍并查重
                if existingTitles.contains(titleInput) {
                    self.showDuplicateAlert = true; return
                } else {
                    let newBook = Book(title: titleInput, author: authorInput)
                    newBook.coverData = selectedCoverData
                    modelContext.insert(newBook)
                }
            }
            
            // 强制保存并推送广播，确保底层列表无缝刷新
            try? modelContext.save()
            NotificationCenter.default.post(name: .libraryDidUpdate, object: nil)
            isPresented = false
        }
}

// MARK: - 预览
#Preview("书籍编辑弹窗") {
    BookEditorSheet(isPresented: .constant(true), bookToEdit: PreviewData.mockBook)
        .padding(40)
        .background(LinearGradient(colors: [.teal, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
}
#endif
