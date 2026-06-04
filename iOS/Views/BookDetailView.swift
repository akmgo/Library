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
        PageShell {
            BookDetailHero(book: book)

            AppCard {
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeader(title: "阅读信息", subtitle: book.progressText)

                    Picker("状态", selection: statusBinding) {
                        ForEach(BookStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: book.progress)
                            .tint(AppTheme.accent)
                        HStack {
                            Text("当前页")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(book.totalPages > 0 ? "\(book.currentPage) / \(book.totalPages)" : "\(book.currentPage)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                        .font(.system(size: 15, weight: .medium))
                    }

                    Stepper("调整当前页", value: pageBinding, in: 0...max(book.totalPages, 1))
                }
            }

            AppCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "快速记录")
                    HStack(spacing: 12) {
                        Button {
                            showAddLog = true
                        } label: {
                            Label("阅读", systemImage: "clock.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button {
                            showAddText = true
                        } label: {
                            Label("摘记", systemImage: "quote.opening")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
            }

            AppCard(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("阅读记录")
                            .font(.system(size: 21, weight: .semibold))
                        Spacer()
                        Text("\(sortedLogs.count)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, sortedLogs.isEmpty ? 0 : 6)

                    if sortedLogs.isEmpty {
                        EmptyHint(title: "暂无阅读记录", message: "手动记录这本书的阅读时长。", systemImage: "calendar")
                            .padding(.horizontal, 18)
                            .padding(.bottom, 12)
                    } else {
                        ForEach(sortedLogs.prefix(6)) { log in
                            ReadingLogRow(log: log)
                            if log.id != sortedLogs.prefix(6).last?.id {
                                Divider()
                                    .padding(.leading, 76)
                            }
                        }
                    }
                }
            }

            AppCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "摘录与笔记", subtitle: "\(sortedTexts.count)")
                    if sortedTexts.isEmpty {
                        EmptyHint(title: "暂无摘记", message: "保存这本书里的句子，或写下自己的笔记。", systemImage: "quote.opening")
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
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    modelContext.delete(book)
                    try? modelContext.save()
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("删除书籍")
            }
        }
        .sheet(isPresented: $showAddLog) {
            AddReadingLogSheet(books: [book], preferredBookID: book.id)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddText) {
            AddBookTextSheet(books: [book], preferredBookID: book.id)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .animation(AppTheme.contentAnimation, value: book.status)
        .animation(AppTheme.contentAnimation, value: book.currentPage)
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

private struct BookDetailHero: View {
    let book: Book

    var body: some View {
        VStack(spacing: 14) {
            BookCover(book: book)
                .frame(width: 164)

            VStack(spacing: 6) {
                Text(book.title)
                    .font(.system(size: 28, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                Text(book.author.isEmpty ? "未填写作者" : book.author)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !book.publisher.isEmpty {
                    Text(book.publisher)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            StatusBadge(status: book.status)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}
