import SwiftUI

struct TodayView: View {
    let books: [Book]
    let logs: [ReadingLog]
    let texts: [BookText]
    let onAddBook: () -> Void
    let onAddLog: () -> Void
    let onAddText: () -> Void

    private var activeBook: Book? {
        books
            .filter { $0.status == .reading }
            .sorted { ($0.lastReadAt ?? $0.createdAt) > ($1.lastReadAt ?? $1.createdAt) }
            .first
    }

    private var todayMinutes: Int {
        let calendar = Calendar.current
        return logs
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.minutes }
    }

    var body: some View {
        PageShell(title: "阅读日记", subtitle: "只记录和书有关的东西") {
            AppCard {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(todayMinutes)")
                            .font(.system(size: 48, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("今日阅读分钟")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        Text("\(books.count)")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("本书")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let activeBook {
                AppCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "当前在读", subtitle: activeBook.progressText)

                        NavigationLink {
                            BookDetailView(book: activeBook)
                        } label: {
                            HStack(spacing: 16) {
                                BookCover(book: activeBook)
                                    .frame(width: 86)

                                VStack(alignment: .leading, spacing: 8) {
                                    StatusBadge(status: activeBook.status)
                                    Text(activeBook.title)
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Text(activeBook.author.isEmpty ? "未填写作者" : activeBook.author)
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)

                                    ProgressView(value: activeBook.progress)
                                        .tint(AppTheme.accent)
                                        .padding(.top, 6)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 12) {
                            Button(action: onAddLog) {
                                Label("记录阅读", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Button(action: onAddText) {
                                Label("写摘录", systemImage: "quote.opening")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            } else {
                AppCard {
                    EmptyHint(title: "还没有在读书籍", message: "添加一本书，或在书籍详情中把状态设为在读。")
                    Button(action: onAddBook) {
                        Label("添加书籍", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            AppCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "最近摘录", subtitle: "\(texts.count)")
                    if texts.isEmpty {
                        EmptyHint(title: "暂无摘录", message: "只保留书摘和笔记，不再收集无关内容。")
                    } else {
                        ForEach(texts.prefix(3)) { text in
                            BookTextRow(text: text)
                            if text.id != texts.prefix(3).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAddBook) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}
