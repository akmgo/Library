import SwiftData
import SwiftUI

struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let book: Book

    @State private var showAddLog = false
    @State private var showAddText = false

    private var sortedLogs: [ReadingLog] {
        book.logs.sorted { $0.date > $1.date }
    }

    private var sortedTexts: [BookText] {
        book.texts.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        PageShell(title: "书籍", subtitle: "详情与记录") {
            VStack(spacing: 14) {
                BookCover(book: book)
                    .frame(width: 156)
                Text(book.title)
                    .font(.system(size: 28, weight: .semibold))
                    .multilineTextAlignment(.center)
                Text(book.author.isEmpty ? "未填写作者" : book.author)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

            AppCard {
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeader(title: "阅读状态", subtitle: book.progressText)
                    Picker("状态", selection: statusBinding) {
                        ForEach(BookStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)

                    ProgressView(value: book.progress)
                        .tint(AppTheme.accent)

                    Stepper("当前页：\(book.currentPage)", value: pageBinding, in: 0...max(book.totalPages, 1))
                }
            }

            AppCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "阅读记录", subtitle: "\(sortedLogs.count)")
                    if sortedLogs.isEmpty {
                        EmptyHint(title: "暂无记录", message: "阅读结束后，手动记录本次时长。")
                    } else {
                        ForEach(sortedLogs.prefix(5)) { log in
                            ReadingLogRow(log: log)
                            if log.id != sortedLogs.prefix(5).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }

            AppCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "摘录与笔记", subtitle: "\(sortedTexts.count)")
                    if sortedTexts.isEmpty {
                        EmptyHint(title: "暂无摘录", message: "只保存这本书相关的摘录和笔记。")
                    } else {
                        ForEach(sortedTexts.prefix(5)) { text in
                            BookTextRow(text: text)
                            if text.id != sortedTexts.prefix(5).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showAddLog = true } label: {
                    Image(systemName: "clock.badge.plus")
                }
                Button { showAddText = true } label: {
                    Image(systemName: "quote.opening")
                }
                Button(role: .destructive) {
                    modelContext.delete(book)
                    try? modelContext.save()
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .sheet(isPresented: $showAddLog) {
            AddReadingLogSheet(books: [book], preferredBookID: book.id)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAddText) {
            AddBookTextSheet(books: [book], preferredBookID: book.id)
                .presentationDetents([.large])
        }
    }

    private var statusBinding: Binding<BookStatus> {
        Binding(
            get: { book.status },
            set: { newStatus in
                book.status = newStatus
                if newStatus == .reading, book.startDate == nil {
                    book.startDate = Date()
                }
                if newStatus == .finished {
                    book.finishDate = Date()
                    if book.totalPages > 0 {
                        book.currentPage = book.totalPages
                    }
                }
                try? modelContext.save()
            }
        )
    }

    private var pageBinding: Binding<Int> {
        Binding(
            get: { book.currentPage },
            set: { newPage in
                book.currentPage = min(max(newPage, 0), max(book.totalPages, 0))
                if book.totalPages > 0, book.currentPage >= book.totalPages {
                    book.status = .finished
                    book.finishDate = Date()
                }
                try? modelContext.save()
            }
        )
    }
}
