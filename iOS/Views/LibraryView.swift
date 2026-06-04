import SwiftUI

struct LibraryView: View {
    let books: [Book]
    let onAddBook: () -> Void

    @State private var searchText = ""

    private var visibleBooks: [Book] {
        let sorted = books.sorted { lhs, rhs in
            (lhs.lastReadAt ?? lhs.createdAt) > (rhs.lastReadAt ?? rhs.createdAt)
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sorted }

        return sorted.filter {
            $0.title.localizedStandardContains(query)
                || $0.author.localizedStandardContains(query)
                || $0.publisher.localizedStandardContains(query)
        }
    }

    private var readingBooks: [Book] {
        visibleBooks.filter { $0.status == .reading }
    }

    var body: some View {
        PageShell {
            if books.isEmpty {
                AppCard {
                    EmptyHint(
                        title: "书架还是空的",
                        message: "先添加一本书。之后的阅读记录、摘录和笔记都会围绕它保存。",
                        systemImage: "books.vertical"
                    )
                    PrimaryActionButton(title: "添加书籍", systemImage: "plus", action: onAddBook)
                }
            } else {
                if !readingBooks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "在读", subtitle: "\(readingBooks.count) 本")
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 14) {
                                ForEach(readingBooks) { book in
                                    NavigationLink {
                                        BookDetailView(book: book)
                                    } label: {
                                        ReadingBookCard(book: book)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .scrollTargetLayout()
                            .padding(.horizontal, AppTheme.pageHorizontalPadding)
                        }
                        .contentMargins(.horizontal, -AppTheme.pageHorizontalPadding, for: .scrollContent)
                        .scrollIndicators(.hidden)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: searchText.isEmpty ? "全部书籍" : "搜索结果", subtitle: "\(visibleBooks.count) 本")
                    if visibleBooks.isEmpty {
                        AppCard {
                            EmptyHint(title: "没有找到书籍", message: "换一个关键词试试。", systemImage: "magnifyingglass")
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 146), spacing: 18)], spacing: 22) {
                            ForEach(visibleBooks) { book in
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
        .navigationTitle("书架")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "搜索书名、作者、出版社")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAddBook) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("添加书籍")
            }
        }
        .animation(AppTheme.contentAnimation, value: visibleBooks.map(\.id))
    }
}

private struct ReadingBookCard: View {
    let book: Book

    var body: some View {
        AppCard(padding: 14, radius: 22) {
            HStack(spacing: 14) {
                BookCover(book: book)
                    .frame(width: 74)

                VStack(alignment: .leading, spacing: 8) {
                    StatusBadge(status: book.status)
                    Text(book.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(book.author.isEmpty ? "未填写作者" : book.author)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    ProgressView(value: book.progress)
                        .tint(AppTheme.accent)
                }
            }
        }
        .frame(width: 286)
    }
}

private struct BookGridItem: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BookCover(book: book)

            VStack(alignment: .leading, spacing: 5) {
                Text(book.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(book.author.isEmpty ? "未填写作者" : book.author)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    ProgressView(value: book.progress)
                        .tint(AppTheme.accent)
                    Text(book.progressText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .padding(.top, 2)
            }
        }
        .contentShape(Rectangle())
    }
}
