import SwiftData
import SwiftUI

struct AddBookTextSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let books: [Book]
    var preferredBookID: UUID?

    @State private var selectedBookID: UUID?
    @State private var kind: BookTextKind = .excerpt
    @State private var content = ""
    @State private var page = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("类型", selection: $kind) {
                        ForEach(BookTextKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("书籍") {
                    Picker("选择书籍", selection: $selectedBookID) {
                        Text("未选择").tag(UUID?.none)
                        ForEach(books) { book in
                            Text(book.title).tag(Optional(book.id))
                        }
                    }
                }

                Section(kind == .excerpt ? "书摘" : "笔记") {
                    TextEditor(text: $content)
                        .frame(minHeight: 180)
                    Stepper(page > 0 ? "第 \(page) 页" : "不记录页码", value: $page, in: 0...5000)
                }
            }
            .navigationTitle(kind == .excerpt ? "添加摘录" : "添加笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(selectedBook == nil || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                selectedBookID = preferredBookID ?? books.first?.id
            }
        }
    }

    private var selectedBook: Book? {
        books.first { $0.id == selectedBookID }
    }

    private func save() {
        guard let selectedBook else { return }
        let text = BookText(
            book: selectedBook,
            kind: kind,
            content: content,
            page: page
        )
        selectedBook.texts.append(text)
        modelContext.insert(text)
        try? modelContext.save()
        dismiss()
    }
}
