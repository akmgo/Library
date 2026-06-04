import SwiftData
import SwiftUI
import PhotosUI

struct AddBookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    var editingBook: Book? = nil

    @State private var title = ""
    @State private var author = ""
    @State private var totalPagesText = ""
    @State private var coverData: Data?
    @State private var selectedCoverItem: PhotosPickerItem?
    @State private var didConfigure = false
    @FocusState private var focusedField: Field?

    private let coverPreviewWidth: CGFloat = 148
    private var coverPreviewHeight: CGFloat { coverPreviewWidth / AppTheme.bookCoverAspectRatio }

    private enum Field {
        case title
        case author
        case totalPages
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("书名", text: $title)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                    TextField("作者", text: $author)
                        .focused($focusedField, equals: .author)
                        .submitLabel(.next)
                    TextField("总页数", text: $totalPagesText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .totalPages)
                        .submitLabel(.done)
                } header: {
                    Text("基础信息")
                }

                Section {
                    PhotosPicker(selection: $selectedCoverItem, matching: .images) {
                        VStack(spacing: 12) {
                            coverPreview

                            Text(coverData == nil ? "点击选择封面" : "点击更换封面")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("封面")
                } footer: {
                    Text("新书会默认保存为待读。")
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background(colorScheme))
            .tint(AppTheme.accent)
            .navigationTitle(editingBook == nil ? "新书" : "编辑书籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { save() }
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                configureForEditingIfNeeded()
                focusedField = .title
            }
            .onSubmit {
                advanceFocus()
            }
            .onChange(of: selectedCoverItem) { _, newItem in
                loadCover(from: newItem)
            }
            .animation(AppTheme.controlAnimation, value: coverData)
        }
    }

    @ViewBuilder
    private var coverPreview: some View {
        if let coverData, let image = UIImage(data: coverData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: coverPreviewWidth, height: coverPreviewHeight)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 16, y: 10)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.insetSurface(colorScheme))
                .frame(width: coverPreviewWidth, height: coverPreviewHeight)
                .overlay {
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 34, weight: .medium))
                        Text("封面")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.accent.opacity(0.72))
                }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && coverData != nil
    }

    private var totalPages: Int {
        Int(totalPagesText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func advanceFocus() {
        switch focusedField {
        case .title:
            focusedField = .author
        case .author:
            focusedField = .totalPages
        default:
            focusedField = nil
        }
    }

    private func loadCover(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            let optimizedData = Self.optimizedCoverData(from: data) ?? data
            await MainActor.run {
                coverData = optimizedData
            }
        }
    }

    private static func optimizedCoverData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let targetAspect = AppTheme.bookCoverAspectRatio
        let sourceAspect = image.size.width / max(image.size.height, 1)
        let cropSize: CGSize

        if sourceAspect > targetAspect {
            cropSize = CGSize(width: image.size.height * targetAspect, height: image.size.height)
        } else {
            cropSize = CGSize(width: image.size.width, height: image.size.width / targetAspect)
        }

        let cropOrigin = CGPoint(
            x: (image.size.width - cropSize.width) / 2,
            y: (image.size.height - cropSize.height) / 2
        )
        let cropRect = CGRect(origin: cropOrigin, size: cropSize)
        let maximumWidth: CGFloat = 900
        let outputWidth = min(maximumWidth, cropSize.width)
        let outputSize = CGSize(width: outputWidth, height: outputWidth / targetAspect)
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        let croppedImage = renderer.image { _ in
            image.draw(
                in: CGRect(
                    x: -cropRect.minX * outputSize.width / cropRect.width,
                    y: -cropRect.minY * outputSize.height / cropRect.height,
                    width: image.size.width * outputSize.width / cropRect.width,
                    height: image.size.height * outputSize.height / cropRect.height
                )
            )
        }
        return croppedImage.jpegData(compressionQuality: 0.84)
    }

    private func save() {
        focusedField = nil
        if let editingBook {
            editingBook.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            editingBook.author = author.trimmingCharacters(in: .whitespacesAndNewlines)
            editingBook.totalPages = totalPages
            if totalPages > 0 {
                editingBook.currentPage = min(editingBook.currentPage, totalPages)
            }
            editingBook.coverData = coverData
        } else {
            let book = Book(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                author: author.trimmingCharacters(in: .whitespacesAndNewlines),
                status: .planned,
                totalPages: totalPages,
                coverData: coverData
            )
            modelContext.insert(book)
        }
        try? modelContext.save()
        dismiss()
    }

    private func configureForEditingIfNeeded() {
        guard !didConfigure, let editingBook else { return }
        title = editingBook.title
        author = editingBook.author
        totalPagesText = editingBook.totalPages > 0 ? "\(editingBook.totalPages)" : ""
        coverData = editingBook.coverData
        didConfigure = true
    }
}

#if DEBUG
#Preview("Add Book Sheet") {
    AddBookSheet()
        .modelContainer(PreviewData.emptyContainer())
}
#endif
