import SwiftData
import SwiftUI

struct AddReadingLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let books: [Book]
    var preferredBookID: UUID?

    @State private var selectedBookID: UUID?
    @State private var date = Date()
    @State private var minutes = 30
    @State private var pageAfterReading = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("书籍") {
                    Picker("选择书籍", selection: $selectedBookID) {
                        Text("未选择").tag(UUID?.none)
                        ForEach(books) { book in
                            Text(book.title).tag(Optional(book.id))
                        }
                    }
                }

                Section("本次阅读") {
                    DatePicker("日期", selection: $date, displayedComponents: [.date])
                    Stepper("\(minutes) 分钟", value: $minutes, in: 5...600, step: 5)
                    Stepper(pageAfterReading > 0 ? "读到第 \(pageAfterReading) 页" : "不记录页码", value: $pageAfterReading, in: 0...5000)
                }
            }
            .navigationTitle("记录阅读")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(selectedBook == nil)
                }
            }
            .onAppear {
                selectedBookID = preferredBookID ?? books.first?.id
                pageAfterReading = selectedBook?.currentPage ?? 0
            }
        }
    }

    private var selectedBook: Book? {
        books.first { $0.id == selectedBookID }
    }

    private func save() {
        guard let selectedBook else { return }
        let log = ReadingLog(
            book: selectedBook,
            date: date,
            minutes: minutes,
            pageAfterReading: pageAfterReading
        )
        selectedBook.logs.append(log)
        selectedBook.status = .reading
        if selectedBook.startDate == nil {
            selectedBook.startDate = date
        }
        if pageAfterReading > 0 {
            selectedBook.currentPage = min(pageAfterReading, max(selectedBook.totalPages, pageAfterReading))
        }
        modelContext.insert(log)
        try? modelContext.save()
        dismiss()
    }
}
