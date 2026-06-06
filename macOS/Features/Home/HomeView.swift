#if os(macOS)
import SwiftData
import SwiftUI

private enum MacLibraryFilter: String, CaseIterable, Identifiable {
    case all
    case planned
    case finished

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .planned: return "想读"
        case .finished: return "已读"
        }
    }

    var status: BookStatus? {
        switch self {
        case .all: return nil
        case .planned: return .planned
        case .finished: return .finished
        }
    }
}

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedBook: Book?

    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @Query(sort: \ReadingSession.date, order: .reverse) private var sessions: [ReadingSession]

    @State private var filter: MacLibraryFilter = .all
    @State private var loggingBook: Book?

    private var sessionMap: [String: [ReadingSession]] {
        Dictionary(grouping: sessions, by: { $0.book?.id ?? "" })
    }

    private var sortedBooks: [Book] {
        books.sorted { lhs, rhs in
            priorityDate(for: lhs) > priorityDate(for: rhs)
        }
    }

    private var readingBooks: [Book] {
        sortedBooks.filter { $0.status == .reading }
    }

    private var visibleBooks: [Book] {
        sortedBooks.filter { book in
            filter.status.map { book.status == $0 } ?? true
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 28) {
                if books.isEmpty {
                    EmptyStateView(
                        systemImage: "books.vertical",
                        title: "书架为空",
                        message: "添加一本书后，阅读记录和摘记会归到这里。",
                        minHeight: 420
                    )
                    .padding(.top, AppPageHeaderMetrics.height + 40)
                } else {
                    if filter == .all, !readingBooks.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            shelfSectionHeader("在读", count: readingBooks.count)

                            LazyVStack(spacing: 14) {
                                ForEach(readingBooks) { book in
                                    MacReadingShelfCard(book: book) {
                                        loggingBook = book
                                    }
                                    .onTapGesture {
                                        selectedBook = book
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        MacLibraryFilterBar(selection: $filter)
                            .frame(maxWidth: 420)

                        shelfSectionHeader(filter == .all ? "全部书籍" : filter.title, count: visibleBooks.count)

                        if visibleBooks.isEmpty {
                            EmptyStateView(
                                systemImage: "books.vertical",
                                title: "\(filter.title)书架为空",
                                message: "这里会展示对应状态的书。",
                                minHeight: 280
                            )
                        } else {
                            bookGrid
                        }
                    }
                }
            }
            .padding(.top, AppPageHeaderMetrics.height + 20)
            .padding(.horizontal, 52)
            .padding(.bottom, 80)
        }
        .background(AppColors.primaryBackground(for: colorScheme))
        .overlay(alignment: .top) {
            AppPageHeader(contentID: "\(books.count)-\(readingBooks.count)-\(filter.rawValue)") {
                AppHeaderTitle("书架", subtitle: "你的书籍、进度与阅读记录。")
            } trailingContent: {
                PageStatsCompact(items: shelfStats)
            }
        }
        .sheet(item: $loggingBook) { book in
            MacQuickReadingLogSheet(book: book)
        }
        .animation(.appContentFade, value: filter)
    }

    private var bookGrid: some View {
        let width: CGFloat = 154
        let columns = [GridItem(.adaptive(minimum: width, maximum: width), spacing: 26)]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 34) {
            ForEach(visibleBooks) { book in
                Button {
                    selectedBook = book
                } label: {
                    BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                        .aspectRatio(2 / 3, contentMode: .fit)
                        .frame(width: width)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(book.title)
            }
        }
    }

    private func shelfSectionHeader(_ title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
            Spacer()
            Text("\(count) 本")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var shelfStats: [PageStatItemData] {
        let counts = Dictionary(grouping: books, by: \.status).mapValues(\.count)
        return [
            PageStatItemData(title: "全部", value: "\(books.count)", color: .indigo),
            PageStatItemData(title: "在读", value: "\(counts[.reading] ?? 0)", color: AppColors.readingAmber),
            PageStatItemData(title: "想读", value: "\(counts[.planned] ?? 0)", color: .teal),
            PageStatItemData(title: "已读", value: "\(counts[.finished] ?? 0)", color: .pink),
        ]
    }

    private func priorityDate(for book: Book) -> Date {
        sessionMap[book.id]?.map(\.startedAt).max()
            ?? book.lastReadAt
            ?? book.startDate
            ?? book.createdAt
    }
}

private struct MacLibraryFilterBar: View {
    @Binding var selection: MacLibraryFilter

    var body: some View {
        Picker("书籍状态", selection: $selection) {
            ForEach(MacLibraryFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }
}

private struct MacReadingShelfCard: View {
    let book: Book
    let onAddLog: () -> Void

    private let coverWidth: CGFloat = 74
    private var coverHeight: CGFloat { coverWidth * 1.5 }

    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: 16) {
                BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                    .frame(width: coverWidth, height: coverHeight)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(book.title)
                                .font(.system(size: 19, weight: .semibold))
                                .lineLimit(2)

                            Text(book.author.isEmpty ? "未填写作者" : book.author)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 12)

                        Button(action: onAddLog) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 25, weight: .semibold))
                                .foregroundStyle(AppColors.readingAmber)
                        }
                        .buttonStyle(.plain)
                        .help("添加阅读记录")
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(book.displayProgress)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        ProgressBarView(progress: book.progressRatio, height: 6)
                    }
                }
                .frame(height: coverHeight, alignment: .top)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous))
    }
}

private struct MacQuickReadingLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let book: Book

    @State private var minutes = 30
    @State private var endAmountText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("添加阅读记录")
                .font(.system(size: 22, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.system(size: 15, weight: .semibold))
                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Stepper(value: $minutes, in: 5...600, step: 5) {
                Text("\(minutes) 分钟")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }

            TextField("当前页码", text: $endAmountText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 360)
        .onAppear {
            endAmountText = book.currentAmount > 0 ? "\(Int(book.currentAmount))" : ""
        }
    }

    private func save() {
        let endedAt = Date()
        let duration = TimeInterval(minutes * 60)
        let startedAt = endedAt.addingTimeInterval(-duration)
        let endAmount = Double(endAmountText) ?? book.currentAmount

        try? ReadingDataService.shared.insertManualReadingSession(
            for: book,
            startedAt: startedAt,
            duration: duration,
            startAmount: book.currentAmount,
            endAmount: endAmount,
            context: modelContext
        )
        dismiss()
    }
}

#endif
