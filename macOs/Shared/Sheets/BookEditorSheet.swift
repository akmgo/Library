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

    let bookToEdit: Book

    @State private var titleInput: String = ""
    @State private var authorInput: String = ""
    @State private var selectedCoverData: Data? = nil

    @State private var isShowingImagePicker = false
    @State private var showDuplicateAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack(spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                Text("编辑档案")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider().opacity(0.5)

            // 内容区
            VStack(spacing: 24) {
                coverEditorView
                    .frame(width: 180, height: 270)

                VStack(alignment: .leading, spacing: 6) {
                    Text("书名")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                    TextField("书名", text: $titleInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .medium))
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("作者")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                    TextField("可留空", text: $authorInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .medium))
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 28)

            Divider().opacity(0.5)

            // 底部操作栏
            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))

                let isFormEmpty = titleInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let hasChanges = titleInput != bookToEdit.title || authorInput != bookToEdit.author || selectedCoverData != bookToEdit.coverData
                let canSave = !isFormEmpty && hasChanges

                Button("保存修改") { saveBook() }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassEffect(canSave ? .regular.tint(.blue).interactive() : .clear.interactive(), in: .rect(cornerRadius: 8))
                    .opacity(canSave ? 1.0 : 0.4)
            }
            .padding(16)
        }
        .frame(width: 420)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .background(WindowTransparentEffect())
        .onAppear {
            titleInput = bookToEdit.title
            authorInput = bookToEdit.author
            selectedCoverData = bookToEdit.coverData
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
                    .frame(width: 180, height: 270)
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
        let cleanedAuthor = authorInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return }

        let hasDuplicateTitle = allBooks.contains { book in
            book.id != bookToEdit.id && book.title == cleanedTitle
        }
        if hasDuplicateTitle {
            showDuplicateAlert = true
            return
        }

        let isCoverChanged = bookToEdit.coverData != selectedCoverData
        bookToEdit.title = cleanedTitle
        bookToEdit.author = cleanedAuthor
        bookToEdit.coverData = selectedCoverData
        if isCoverChanged { ImageCacheManager.shared.removeImage(forKey: "cover_img_\(bookToEdit.id)") }
        ReadingDataService.shared.normalizeBook(bookToEdit)
        try? modelContext.save()

        isPresented = false
    }
}
#endif
