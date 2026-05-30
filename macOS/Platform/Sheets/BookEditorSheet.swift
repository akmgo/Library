#if os(macOS)
import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Book editor (create & edit)

struct BookEditorSheet: View {
    @Query var allBooks: [Book]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Binding var isPresented: Bool

    var bookToEdit: Book? = nil

    @State private var titleInput: String = ""
    @State private var authorInput: String = ""
    @State private var totalPages: Double = 0
    @State private var selectedCoverData: Data? = nil

    @State private var isShowingImagePicker = false
    @State private var showDuplicateAlert = false

    private var isEdit: Bool { bookToEdit != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                Text(isEdit ? "编辑档案" : "添加图书")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider().opacity(0.5)

            VStack(spacing: 24) {
                coverEditorView
                    .frame(width: 180, height: 270)

                VStack(alignment: .leading, spacing: 6) {
                    Text("书名").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                    TextField("书名", text: $titleInput)
                        .textFieldStyle(.plain).font(.system(size: 15, weight: .medium)).padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("作者").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                    TextField("可留空", text: $authorInput)
                        .textFieldStyle(.plain).font(.system(size: 15, weight: .medium)).padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("总页数").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                    TextField("0", value: $totalPages, format: .number.precision(.fractionLength(0)))
                        .textFieldStyle(.plain).font(.system(size: 15, weight: .medium)).padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 28)

            Divider().opacity(0.5)

            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                    .keyboardShortcut(.cancelAction).buttonStyle(.plain)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(AppColors.innerBlock(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.innerStroke(for: colorScheme), lineWidth: 1))

                let isFormEmpty = titleInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let hasChanges: Bool = {
                    guard let book = bookToEdit else { return !isFormEmpty }
                    return titleInput != book.title || authorInput != book.author
                        || totalPages != book.totalAmount || selectedCoverData != book.coverData
                }()
                let canSave = !isFormEmpty && hasChanges

                Button(isEdit ? "保存修改" : "入库") { saveBook() }
                    .buttonStyle(.plain).keyboardShortcut(.defaultAction).disabled(!canSave)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(canSave ? Color.blue : Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(canSave ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1))
                    .opacity(canSave ? 1.0 : 0.4)
            }
            .padding(16)
        }
        .frame(width: 420)
        .background(Color(nsColor: .windowBackgroundColor), in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 24, y: 12)
        .background(WindowTransparentEffect())
        .onAppear {
            if let book = bookToEdit {
                titleInput = book.title
                authorInput = book.author
                totalPages = book.totalAmount
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
                    .resizable().scaledToFill()
                    .frame(width: 180, height: 270)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: Color.black.opacity(0.2), radius: 6, y: 3)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(AppColors.innerBlock(for: colorScheme))
                    RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus").font(.system(size: 32, weight: .light)).foregroundColor(.blue.opacity(0.8))
                        Text("设定视觉封面").font(.system(size: 13, weight: .bold)).foregroundColor(.primary)
                        Text("比例 2:3").font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
                .frame(width: 180, height: 270)
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

    private func saveBook() {
        let cleanedTitle = titleInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return }

        if let book = bookToEdit {
            // Edit existing
            let hasDuplicateTitle = allBooks.contains { $0.id != book.id && $0.title == cleanedTitle }
            if hasDuplicateTitle { showDuplicateAlert = true; return }
            book.title = cleanedTitle
            book.author = authorInput.trimmingCharacters(in: .whitespacesAndNewlines)
            book.totalAmount = max(totalPages, 0)
            if book.coverData != selectedCoverData {
                book.coverData = selectedCoverData
                ImageCacheManager.shared.removeImage(forKey: "cover_img_\(book.id)")
            }
            ReadingDataService.shared.normalizeBook(book)
        } else {
            // Create new
            let hasDuplicateTitle = allBooks.contains { $0.title == cleanedTitle }
            if hasDuplicateTitle { showDuplicateAlert = true; return }
            let book = Book(
                title: cleanedTitle,
                author: authorInput.trimmingCharacters(in: .whitespacesAndNewlines),
                coverData: selectedCoverData,
                status: .unread,
                totalAmount: max(totalPages, 0)
            )
            modelContext.insert(book)
        }
        try? modelContext.save()
        isPresented = false
    }
}
#endif
