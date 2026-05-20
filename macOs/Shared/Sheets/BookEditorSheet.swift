#if os(macOS)
import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - V1 book record editor

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

    @State private var isSearchingCloud = false
    @State private var showSearchResults = false
    @State private var searchResults: [BookSearchResult] = []
    @State private var searchError: String? = nil

    var body: some View {
        let isEdit = bookToEdit != nil

        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)

                Text(isEdit ? "编辑档案" : "添加图书")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider().opacity(0.5)

            HStack(spacing: 32) {
                coverEditorView
                    .frame(width: 160, height: 240)

                rightInfoPanel
                    .frame(width: 260, height: 240)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, minHeight: 340, alignment: .center)

            Divider().opacity(0.5)

            HStack {
                Spacer()

                Button("取消") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 6))

                let isFormEmpty = titleInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let hasChanges = bookToEdit == nil ? true : (titleInput != bookToEdit?.title || authorInput != bookToEdit?.author || selectedCoverData != bookToEdit?.coverData)
                let canSave = !isFormEmpty && hasChanges

                Button(isEdit ? "保存修改" : "确认入库") { saveBook() }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassEffect(canSave ? .regular.tint(.blue).interactive() : .clear.interactive(), in: .rect(cornerRadius: 6))
                    .opacity(canSave ? 1.0 : 0.4)
            }
            .padding(16)
        }
        .frame(width: 520)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .background(WindowTransparentEffect())
        .onAppear {
            if let book = bookToEdit {
                titleInput = book.title
                authorInput = book.author
                selectedCoverData = book.coverData
            }
        }
        .alert("书名重复", isPresented: $showDuplicateAlert) {
            Button("好的", role: .cancel) {}
        } message: { Text("您当前添加的书籍已存在，请检查书库。") }
    }

    private var coverEditorView: some View {
        Button(action: { isShowingImagePicker = true }) {
            if let data = selectedCoverData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: Color.black.opacity(0.2), radius: 6, y: 3)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            } else {
                ZStack {
                    Color.clear.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8.0))
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(.blue.opacity(0.8))
                        Text("设定视觉封面")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                        Text("比例 2:3")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 160, height: 240)
            }
        }
        .buttonStyle(.plain)
        .fileImporter(isPresented: $isShowingImagePicker, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            if let file = try? result.get().first, file.startAccessingSecurityScopedResource() {
                defer { file.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: file) {
                    DispatchQueue.main.async { self.selectedCoverData = data }
                }
            }
        }
        .contextMenu {
            if selectedCoverData != nil {
                Button("移除自定义封面") { withAnimation { selectedCoverData = nil } }
            }
        }
    }

    private var rightInfoPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("书名")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    TextField("书名", text: $titleInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium))
                        .onSubmit { performInlineSearch() }
                        .onChange(of: titleInput) { _, newValue in
                            if newValue.trimmingCharacters(in: .whitespaces).isEmpty { showSearchResults = false }
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
                    .popover(isPresented: $showSearchResults, arrowEdge: .trailing) {
                        InlineBookSearchResultsPopover(results: searchResults, error: searchError, isLoading: isSearchingCloud, onSelect: applySearchResult)
                    }
                }
                .padding(10)
                .glassEffect(in: .rect(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("作者")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                TextField("可留空", text: $authorInput)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .glassEffect(in: .rect(cornerRadius: 6))
                    .font(.system(size: 14))
            }

            Text("V1 仅保存书籍记录，不绑定或解析本地电子书文件。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    private func performInlineSearch() {
        guard !titleInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearchingCloud = true
        showSearchResults = true
        searchError = nil
        searchResults.removeAll()

        Task { @MainActor in
            do {
                let results = try await BookMetadataSearchManager.shared.search(query: titleInput)
                if results.isEmpty { searchError = "未能找到相关书籍" } else { searchResults = results }
            } catch {
                searchError = "查询受阻：\(error.localizedDescription)"
            }
            isSearchingCloud = false
        }
    }

    private func applySearchResult(_ result: BookSearchResult, fetchedCoverData: Data?) {
        showSearchResults = false
        withAnimation(.snappy) {
            titleInput = result.title
            authorInput = result.author
            selectedCoverData = fetchedCoverData
        }
        if fetchedCoverData == nil {
            Task { @MainActor in
                if let coverData = await BookMetadataSearchManager.shared.fetchCoverData(from: result.coverURL) {
                    withAnimation(.spring()) { self.selectedCoverData = coverData }
                }
            }
        }
    }

    private func saveBook() {
        let cleanedTitle = titleInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedAuthor = authorInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return }

        let existingTitles = Set(allBooks.map { $0.title })
        if let book = bookToEdit {
            let isCoverChanged = book.coverData != selectedCoverData
            book.title = cleanedTitle
            book.author = cleanedAuthor
            book.coverData = selectedCoverData
            if isCoverChanged { ImageCacheManager.shared.removeImage(forKey: "cover_img_\(book.id)") }
        } else {
            if existingTitles.contains(cleanedTitle) {
                showDuplicateAlert = true
                return
            }
            let newBook = Book(title: cleanedTitle, author: cleanedAuthor, coverData: selectedCoverData)
            modelContext.insert(newBook)
        }

        try? modelContext.save()
        NotificationCenter.default.post(name: .libraryDidUpdate, object: nil)
        isPresented = false
    }
}
#endif
