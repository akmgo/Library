import SwiftUI

struct LibraryView: View {
    let books: [Book]
    let onAddBook: () -> Void

    private var groupedBooks: [(BookStatus, [Book])] {
        BookStatus.allCases.map { status in
            let items = books
                .filter { $0.status == status }
                .sorted { ($0.lastReadAt ?? $0.createdAt) > ($1.lastReadAt ?? $1.createdAt) }
            return (status, items)
        }
        .filter { !$0.1.isEmpty }
    }

    var body: some View {
        PageShell(title: "书库", subtitle: "所有记录都从书开始") {
            if books.isEmpty {
                AppCard {
                    EmptyHint(title: "书库为空", message: "添加一本书，开始建立自己的阅读记录。")
                    Button(action: onAddBook) {
                        Label("添加书籍", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ForEach(groupedBooks, id: \.0.id) { status, items in
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: status.title, subtitle: "\(items.count)")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), spacing: 16)], spacing: 18) {
                            ForEach(items) { book in
                                NavigationLink {
                                    BookDetailView(book: book)
                                } label: {
                                    BookGridItem(book: book)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAddBook) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

private struct BookGridItem: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BookCover(book: book)
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(book.author.isEmpty ? "未填写作者" : book.author)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                ProgressView(value: book.progress)
                    .tint(AppTheme.accent)
                    .padding(.top, 4)
            }
        }
    }
}
