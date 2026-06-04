import SwiftData
import SwiftUI

private enum LibraryStatusFilter: String, CaseIterable, Identifiable {
    case all
    case planned
    case finished

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .planned: "待读"
        case .finished: "已读"
        }
    }

    var status: BookStatus? {
        switch self {
        case .all: nil
        case .planned: .planned
        case .finished: .finished
        }
    }
}

struct LibraryView: View {
    let books: [Book]
    let onAddBook: () -> Void

    @State private var statusFilter: LibraryStatusFilter = .all
    @State private var loggingBook: Book?

    private var sortedBooks: [Book] {
        books.sorted { lhs, rhs in
            (lhs.lastReadAt ?? lhs.createdAt) > (rhs.lastReadAt ?? rhs.createdAt)
        }
    }

    private var visibleBooks: [Book] {
        sortedBooks.filter { book in
            statusFilter.status.map { book.status == $0 } ?? true
        }
    }

    private var readingBooks: [Book] {
        sortedBooks.filter { $0.status == .reading }
    }

    var body: some View {
        PageShell {
            if books.isEmpty {
                AppEmptyState(
                    title: "书架为空",
                    message: "添加一本书后，阅读记录和摘记会归到这里。",
                    systemImage: "books.vertical"
                )
            } else {
                if statusFilter == .all, !readingBooks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "在读", subtitle: "\(readingBooks.count) 本")

                        LazyVStack(spacing: 12) {
                            ForEach(readingBooks) { book in
                                ReadingBookCard(book: book) {
                                    loggingBook = book
                                }
                            }
                        }
                    }
                    .transition(.opacity)
                }

                VStack(alignment: .leading, spacing: 12) {
                    LibraryStatusFilterBar(selection: $statusFilter)

                    SectionHeader(title: shelfTitle, subtitle: "\(visibleBooks.count) 本")
                    if visibleBooks.isEmpty {
                        AppEmptyState(
                            title: "\(statusFilter.title)书架为空",
                            message: "这里会展示对应状态的书。",
                            systemImage: "books.vertical",
                            style: .compact
                        )
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 22),
                                GridItem(.flexible(), spacing: 22)
                            ],
                            spacing: 26
                        ) {
                            ForEach(visibleBooks) { book in
                                NavigationLink {
                                    BookDetailView(book: book)
                                } label: {
                                    BookShelfCoverItem(book: book)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(book.title)
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: onAddBook) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("添加书籍")
            }
        }
        .animation(.easeInOut(duration: 0.18), value: statusFilter)
        .sheet(item: $loggingBook) { book in
            AddReadingLogSheet(books: [book], preferredBookID: book.id)
                .presentationDetents([.height(390)])
                .presentationDragIndicator(.visible)
        }
    }

    private var shelfTitle: String {
        return statusFilter == .all ? "全部书籍" : statusFilter.title
    }
}

private struct LibraryStatusFilterBar: View {
    @Binding var selection: LibraryStatusFilter

    var body: some View {
        Picker("书籍状态", selection: $selection) {
            ForEach(LibraryStatusFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("筛选书籍状态")
    }
}

private struct ReadingBookCard: View {
    let book: Book
    let onAddLog: () -> Void

    private let coverWidth: CGFloat = 64
    private var coverHeight: CGFloat { coverWidth / AppTheme.bookCoverAspectRatio }

    var body: some View {
        AppCard(padding: 12, radius: AppTheme.cardRadius) {
            HStack(alignment: .top, spacing: 12) {
                BookCover(book: book)
                    .frame(width: coverWidth)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        NavigationLink {
                            BookDetailView(book: book)
                        } label: {
                            ReadingBookCardTitle(book: book)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())

                        Button(action: onAddLog) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 32, height: 32)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("添加阅读记录")
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.progressText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        ProgressView(value: book.progress)
                            .tint(AppTheme.accent)
                    }
                }
                .frame(height: coverHeight, alignment: .top)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
    }
}

private struct ReadingBookCardTitle: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text(book.author.isEmpty ? "未填写作者" : book.author)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct BookShelfCoverItem: View {
    let book: Book

    var body: some View {
        BookCover(book: book)
            .frame(maxWidth: .infinity)
            .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 7)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#if DEBUG
#Preview("Library") {
    PreviewHost { data in
        NavigationStack {
            LibraryView(books: data.books, onAddBook: {})
        }
    }
}

#Preview("Library Empty") {
    NavigationStack {
        LibraryView(books: [], onAddBook: {})
    }
    .modelContainer(PreviewData.emptyContainer())
}
#endif
