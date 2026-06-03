import SwiftData
import SwiftUI

struct AddBookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var author = ""
    @State private var publisher = ""
    @State private var totalPages = 0
    @State private var status: BookStatus = .planned

    var body: some View {
        NavigationStack {
            Form {
                Section("书籍") {
                    TextField("书名", text: $title)
                    TextField("作者", text: $author)
                    TextField("出版社", text: $publisher)
                }

                Section("阅读") {
                    Picker("状态", selection: $status) {
                        ForEach(BookStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    Stepper(totalPages > 0 ? "总页数：\(totalPages)" : "未设置总页数", value: $totalPages, in: 0...5000, step: 10)
                }
            }
            .navigationTitle("添加书籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let book = Book(
            title: title,
            author: author,
            publisher: publisher,
            status: status,
            totalPages: totalPages
        )
        modelContext.insert(book)
        try? modelContext.save()
        dismiss()
    }
}
