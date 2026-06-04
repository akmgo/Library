import SwiftData
import SwiftUI

struct AddReadingLogSheet: View {
    private static let maximumPageProgress = 999_999

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    let books: [Book]
    var preferredBookID: UUID?
    var editingLog: ReadingLog?

    @State private var selectedBookID: UUID?
    @State private var date = Date()
    @State private var minutes = 30
    @State private var pageAfterReading = 0
    @State private var pageAfterReadingText = ""
    @State private var didConfigure = false
    @FocusState private var pageFieldFocused: Bool

    private var readingBooks: [Book] {
        books.filter { $0.status == .reading }
    }

    private var selectableBooks: [Book] {
        guard let editingBook = editingLog?.book, !readingBooks.contains(where: { $0.id == editingBook.id }) else {
            return readingBooks
        }
        return [editingBook] + readingBooks
    }

    private var shouldShowBookPicker: Bool {
        selectableBooks.count > 1 || editingLog != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if selectableBooks.isEmpty {
                    Section {
                        AppEmptyState(
                            title: "暂无在读书籍",
                            message: "先把一本书设为在读，再记录阅读时长。",
                            systemImage: "books.vertical",
                            style: .compact
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    }
                } else {
                    if shouldShowBookPicker {
                        Section {
                            Picker("书籍", selection: $selectedBookID) {
                                ForEach(selectableBooks) { book in
                                    Text(book.title).tag(Optional(book.id))
                                }
                            }
                        } header: {
                            Text("本次阅读")
                        }
                    }

                    Section {
                        DatePicker("日期", selection: $date, displayedComponents: [.date])
                            .environment(\.locale, AppDateText.chineseLocale)

                        Stepper(value: $minutes, in: 5...600, step: 5) {
                            LabeledContent("时长") {
                                Text("\(minutes) 分钟")
                                    .foregroundStyle(AppTheme.secondaryText(colorScheme))
                                    .contentTransition(.numericText())
                            }
                        }

                        VStack(spacing: 8) {
                            Stepper(value: pageAfterReadingBinding, in: 0...Self.maximumPageProgress) {
                                LabeledContent("进度") {
                                    Text(pageAfterReading > 0 ? "第 \(pageAfterReading) 页" : "不记录")
                                        .foregroundStyle(AppTheme.secondaryText(colorScheme))
                                        .contentTransition(.numericText())
                                }
                            }

                            TextField("手动输入页码", text: $pageAfterReadingText)
                                .keyboardType(.numberPad)
                                .textInputAutocapitalization(.never)
                                .focused($pageFieldFocused)
                        }
                    } footer: {
                        Text("这里只记录已经发生的阅读，不设置目标。")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background(colorScheme))
            .tint(AppTheme.accent)
            .navigationTitle(editingLog == nil ? "记录阅读" : "编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(selectedBook == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        pageFieldFocused = false
                    }
                }
            }
            .onAppear {
                configureInitialValuesIfNeeded()
            }
            .onChange(of: pageAfterReadingText) { _, newValue in
                let normalized = newValue.filter(\.isNumber)
                if normalized != newValue {
                    pageAfterReadingText = normalized
                    return
                }
                pageAfterReading = min(Int(normalized) ?? 0, Self.maximumPageProgress)
            }
            .onChange(of: selectedBookID) { _, _ in
                guard editingLog == nil else { return }
                syncPageProgress(selectedBook?.currentPage ?? 0)
            }
            .animation(AppTheme.controlAnimation, value: minutes)
            .animation(AppTheme.controlAnimation, value: pageAfterReading)
        }
    }

    private var selectedBook: Book? {
        selectableBooks.first { $0.id == selectedBookID }
    }

    private var pageAfterReadingBinding: Binding<Int> {
        Binding(
            get: { pageAfterReading },
            set: { newValue in
                pageAfterReading = newValue
                pageAfterReadingText = newValue > 0 ? "\(newValue)" : ""
            }
        )
    }

    private func save() {
        guard let selectedBook else { return }
        pageFieldFocused = false
        if let editingLog {
            let previousBook = editingLog.book
            editingLog.book = selectedBook
            editingLog.date = date
            editingLog.minutes = minutes
            editingLog.pageAfterReading = pageAfterReading
            if !selectedBook.logs.contains(where: { $0.id == editingLog.id }) {
                selectedBook.logs.append(editingLog)
            }
            ReadingLogMetrics.refreshCurrentPage(for: previousBook)
            ReadingLogMetrics.refreshCurrentPage(for: selectedBook)
        } else {
            let log = ReadingLog(
                book: selectedBook,
                date: date,
                minutes: minutes,
                pageAfterReading: pageAfterReading
            )
            selectedBook.logs.append(log)
            modelContext.insert(log)
            ReadingLogMetrics.refreshCurrentPage(for: selectedBook)
        }
        if editingLog == nil {
            selectedBook.status = .reading
        }
        if selectedBook.startDate == nil {
            selectedBook.startDate = date
        }
        if pageAfterReading > 0 {
            selectedBook.currentPage = min(pageAfterReading, max(selectedBook.totalPages, pageAfterReading))
        }
        try? modelContext.save()
        dismiss()
    }

    private func configureInitialValuesIfNeeded() {
        guard !didConfigure else { return }
        if let editingLog {
            selectedBookID = editingLog.book?.id ?? preferredBookID ?? selectableBooks.first?.id
            date = editingLog.date
            minutes = editingLog.minutes
            syncPageProgress(editingLog.pageAfterReading)
        } else {
            let preferredBook = selectableBooks.first { $0.id == preferredBookID }
            selectedBookID = preferredBook?.id ?? selectableBooks.first?.id
            syncPageProgress(selectedBook?.currentPage ?? 0)
        }
        didConfigure = true
    }

    private func syncPageProgress(_ value: Int) {
        pageAfterReading = min(max(value, 0), Self.maximumPageProgress)
        pageAfterReadingText = pageAfterReading > 0 ? "\(pageAfterReading)" : ""
    }
}

#if DEBUG
#Preview("Add Reading Log Sheet") {
    PreviewHost { data in
        AddReadingLogSheet(books: data.books)
    }
}

#Preview("Add Reading Log Empty") {
    AddReadingLogSheet(books: [])
        .modelContainer(PreviewData.emptyContainer())
}
#endif
