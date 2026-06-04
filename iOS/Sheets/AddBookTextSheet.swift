import SwiftData
import SwiftUI

struct AddBookTextSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    let books: [Book]
    var preferredBookID: UUID?
    var editingText: BookText?

    @State private var selectedBookID: UUID?
    @State private var kind: BookTextKind = .excerpt
    @State private var content = ""
    @State private var pageText = ""
    @State private var didConfigure = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case content
        case page
    }

    var body: some View {
        NavigationStack {
            Form {
                if books.isEmpty {
                    Section {
                        AppEmptyState(
                            title: "还没有书",
                            message: "摘录和笔记需要先关联一本书。",
                            systemImage: "quote.opening",
                            style: .compact
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    }
                } else {
                    Section {
                        Picker("类型", selection: $kind) {
                            ForEach(BookTextKind.allCases) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section {
                        Picker("书籍", selection: $selectedBookID) {
                            ForEach(books) { book in
                                Text(book.title).tag(Optional(book.id))
                            }
                        }
                    }

                    Section {
                        ZStack(alignment: .topLeading) {
                            if content.isEmpty {
                                Text(kind == .excerpt ? "输入书中值得留下的句子" : "输入这本书带来的想法")
                                    .foregroundStyle(AppTheme.tertiaryText(colorScheme))
                                    .padding(.top, 8)
                                    .padding(.horizontal, 5)
                                    .allowsHitTesting(false)
                            }

                            TextEditor(text: $content)
                                .focused($focusedField, equals: .content)
                                .frame(minHeight: 190)
                                .scrollContentBackground(.hidden)
                        }

                        TextField("页码", text: $pageText)
                            .keyboardType(.numberPad)
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .page)
                    } header: {
                        Text(kind == .excerpt ? "书摘" : "笔记")
                    } footer: {
                        if page == 0 {
                            Text("页码可留空。")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background(colorScheme))
            .tint(AppTheme.accent)
            .navigationTitle(editingText == nil ? kind.title : "编辑\(kind.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(selectedBook == nil || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                configureInitialValuesIfNeeded()
                focusedField = books.isEmpty ? nil : .content
            }
            .animation(AppTheme.controlAnimation, value: kind)
        }
    }

    private var selectedBook: Book? {
        books.first { $0.id == selectedBookID }
    }

    private var page: Int {
        Int(pageText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func save() {
        guard let selectedBook else { return }
        focusedField = nil
        if let editingText {
            editingText.kind = kind
            editingText.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            editingText.page = page
            editingText.book = selectedBook
        } else {
            let text = BookText(
                book: selectedBook,
                kind: kind,
                content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                page: page
            )
            selectedBook.texts.append(text)
            modelContext.insert(text)
        }
        try? modelContext.save()
        dismiss()
    }

    private func configureInitialValuesIfNeeded() {
        guard !didConfigure else { return }
        if let editingText {
            selectedBookID = editingText.book?.id ?? preferredBookID ?? books.first?.id
            kind = editingText.kind
            content = editingText.content
            pageText = editingText.page > 0 ? "\(editingText.page)" : ""
        } else if selectedBookID == nil {
            selectedBookID = preferredBookID ?? books.first?.id
        }
        didConfigure = true
    }
}

#if DEBUG
#Preview("Add Book Text Sheet") {
    PreviewHost { data in
        AddBookTextSheet(books: data.books)
    }
}

#Preview("Add Book Text Empty") {
    AddBookTextSheet(books: [])
        .modelContainer(PreviewData.emptyContainer())
}
#endif
