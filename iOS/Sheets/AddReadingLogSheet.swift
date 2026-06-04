import SwiftData
import SwiftUI

struct AddReadingLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    let books: [Book]
    var preferredBookID: UUID?

    @State private var selectedBookID: UUID?
    @State private var date = Date()
    @State private var minutes = 30
    @State private var pageAfterReading = 0

    var body: some View {
        NavigationStack {
            Form {
                if books.isEmpty {
                    Section {
                        EmptyHint(
                            title: "还没有书",
                            message: "先在书架添加一本书，再记录阅读时长。",
                            systemImage: "books.vertical"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    }
                } else {
                    Section {
                        Picker("书籍", selection: $selectedBookID) {
                            ForEach(books) { book in
                                Text(book.title).tag(Optional(book.id))
                            }
                        }
                    } header: {
                        Text("本次阅读")
                    }

                    Section {
                        DatePicker("日期", selection: $date, displayedComponents: [.date])

                        Stepper(value: $minutes, in: 5...600, step: 5) {
                            LabeledContent("时长") {
                                Text("\(minutes) 分钟")
                                    .foregroundStyle(AppTheme.secondaryText(colorScheme))
                                    .contentTransition(.numericText())
                            }
                        }

                        Stepper(value: $pageAfterReading, in: 0...5000) {
                            LabeledContent("进度") {
                                Text(pageAfterReading > 0 ? "第 \(pageAfterReading) 页" : "不记录")
                                    .foregroundStyle(AppTheme.secondaryText(colorScheme))
                                    .contentTransition(.numericText())
                            }
                        }
                    } footer: {
                        Text("这里只记录已经发生的阅读，不设置目标。")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background(colorScheme))
            .tint(AppTheme.accent)
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
                if selectedBookID == nil {
                    selectedBookID = preferredBookID ?? books.first?.id
                }
                pageAfterReading = selectedBook?.currentPage ?? 0
            }
            .animation(AppTheme.controlAnimation, value: minutes)
            .animation(AppTheme.controlAnimation, value: pageAfterReading)
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
