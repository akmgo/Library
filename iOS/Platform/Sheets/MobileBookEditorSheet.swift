#if os(iOS)
import PhotosUI
import SwiftData
import SwiftUI

// MARK: - V1 mobile book record editor

struct MobileBookEditorSheet: View {
    @Query var allBooks: [Book]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var bookToEdit: Book? = nil

    @State private var titleInput: String = ""
    @State private var authorInput: String = ""
    @State private var totalPages: Double = 0
    @State private var selectedCoverData: Data? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showDuplicateAlert = false

    private var isEdit: Bool { bookToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        coverEditorView
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .listRowBackground(Color.clear)
                }

                Section(header: Text("书籍信息")) {
                    HStack {
                        Text("书名").foregroundColor(.secondary).frame(width: 40, alignment: .leading)
                        TextField("必填", text: $titleInput)
                    }

                    HStack {
                        Text("作者").foregroundColor(.secondary).frame(width: 40, alignment: .leading)
                        TextField("可留空", text: $authorInput)
                    }

                    HStack {
                        Text("页数").foregroundColor(.secondary).frame(width: 40, alignment: .leading)
                        TextField("0", value: $totalPages, format: .number.precision(.fractionLength(0)))
                            .keyboardType(.numberPad)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.primaryBackground(for: colorScheme))
            .navigationTitle(isEdit ? "编辑档案" : "添加图书")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.secondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    let isFormEmpty = titleInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    let hasChanges = bookToEdit == nil ? true : (titleInput != bookToEdit?.title || authorInput != bookToEdit?.author || selectedCoverData != bookToEdit?.coverData)

                    Button(isEdit ? "保存" : "入库") { saveBook() }
                        .fontWeight(.bold)
                        .disabled(isFormEmpty || !hasChanges)
                }
            }
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
    }

    private var coverEditorView: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
            if let data = selectedCoverData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 6, y: 3)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppColors.secondaryBackground(for: colorScheme))
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))

                    VStack(spacing: AppSpacing.s) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(.blue.opacity(0.8))
                        Text("设定封面")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                .frame(width: 140, height: 210)
            }
        }
        .buttonStyle(.plain)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    await MainActor.run { self.selectedCoverData = data }
                }
            }
        }
        .contextMenu {
            if selectedCoverData != nil {
                Button("移除自定义封面", role: .destructive) { withAnimation { selectedCoverData = nil } }
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
            book.totalAmount = max(totalPages, 0)
            book.coverData = selectedCoverData
            if isCoverChanged { ImageCacheManager.shared.removeImage(forKey: "cover_img_\(book.id)") }
            ReadingDataService.shared.normalizeBook(book)
            try? modelContext.save()
        } else {
            if existingTitles.contains(cleanedTitle) {
                showDuplicateAlert = true
                return
            }
            let newBook = Book(title: cleanedTitle, author: cleanedAuthor, coverData: selectedCoverData, totalAmount: max(totalPages, 0))
            try? ReadingDataService.shared.insertBook(newBook, context: modelContext)
        }

        dismiss()
    }
}

#if DEBUG
private struct PreviewMobileBookEditor: View {
    @State private var isPresented = true
    var body: some View {
        PreviewWithData {
            Color.clear
                .sheet(isPresented: $isPresented) {
                    MobileBookEditorSheet()
                }
        }
    }
}

#Preview("编辑书籍弹窗") {
    PreviewMobileBookEditor()
}
#endif


#endif
