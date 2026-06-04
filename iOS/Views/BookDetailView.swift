import SwiftData
import SwiftUI

struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let book: Book

    @State private var showEditBook = false
    @State private var showAddText = false
    @State private var editingText: BookText?
    @State private var deletingText: BookText?
    @State private var showDeleteBookConfirmation = false

    private var sortedLogs: [ReadingLog] {
        book.logs.sorted { $0.date > $1.date }
    }

    private var pagesReadByLogID: [UUID: Int] {
        ReadingLogMetrics.pagesReadByLogID(for: sortedLogs)
    }

    private var sortedTexts: [BookText] {
        book.texts.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        PageShell {
            BookDetailHero(book: book)

            AppCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "阅读状态", subtitle: book.status.title)

                    Picker("状态", selection: statusBinding) {
                        ForEach(BookStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .tint(AppTheme.accent)

            AppCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "阅读日期", subtitle: dateRangeCaption)

                    VStack(spacing: 0) {
                        OptionalBookDateRow(
                            title: "开始日期",
                            date: optionalStartDateBinding,
                            fallbackDate: sortedLogs.last?.date ?? Date()
                        )

                        Divider()
                            .overlay(AppTheme.stroke(colorScheme))

                        OptionalBookDateRow(
                            title: "结束日期",
                            date: optionalFinishDateBinding,
                            fallbackDate: Date()
                        )
                    }
                }
            }

            AppCard(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("最近阅读")
                            .font(.system(size: 21, weight: .semibold))
                        Spacer()
                        if !sortedLogs.isEmpty {
                            NavigationLink {
                                BookDetailAllReadingLogsView(book: book)
                            } label: {
                                Text("全部")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(AppTheme.accent)
                        } else {
                            Text("共 0 条")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, sortedLogs.isEmpty ? 0 : 6)

                    if sortedLogs.isEmpty {
                        AppEmptyState(
                            title: "暂无阅读记录",
                            message: "手动记录这本书的阅读时长。",
                            systemImage: "calendar",
                            style: .compact
                        )
                            .padding(.horizontal, 18)
                            .padding(.bottom, 12)
                    } else {
                        ForEach(sortedLogs.prefix(6)) { log in
                            BookDetailReadingLogRow(log: log, pagesRead: pagesReadByLogID[log.id])
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
                    HStack(alignment: .firstTextBaseline) {
                        Text("摘录与笔记")
                            .font(.system(size: 21, weight: .semibold))
                        Spacer()
                        if !sortedTexts.isEmpty {
                            NavigationLink {
                                BookDetailAllTextsView(book: book)
                            } label: {
                                Text("全部")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(AppTheme.accent)
                        } else {
                            Text("0")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if sortedTexts.isEmpty {
                        AppEmptyState(
                            title: "暂无摘记",
                            message: "保存书里的句子，或写下自己的想法。",
                            systemImage: "quote.opening",
                            style: .compact
                        )
                    } else {
                        ForEach(sortedTexts.prefix(5)) { text in
                            BookTextRow(text: text, showsBookTitle: false)
                                .contextMenu {
                                    Button {
                                        editingText = text
                                    } label: {
                                        Label("编辑", systemImage: "pencil")
                                    }

                                    Button(role: .destructive) {
                                        deletingText = text
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            if text.id != sortedTexts.prefix(5).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEditBook = true
                    } label: {
                        Label("编辑书籍", systemImage: "pencil")
                    }

                    Button {
                        showAddText = true
                    } label: {
                        Label("添加摘记", systemImage: "quote.opening")
                    }

                    Button(role: .destructive) {
                        showDeleteBookConfirmation = true
                    } label: {
                        Label("删除书籍", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("更多操作")
            }
        }
        .sheet(isPresented: $showEditBook) {
            AddBookSheet(editingBook: book)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddText) {
            AddBookTextSheet(books: [book], preferredBookID: book.id)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingText) { text in
            AddBookTextSheet(books: [book], preferredBookID: book.id, editingText: text)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "删除这本书？",
            isPresented: $showDeleteBookConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除书籍", role: .destructive) {
                modelContext.delete(book)
                try? modelContext.save()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会同时删除它的阅读记录、摘录和笔记。")
        }
        .confirmationDialog(
            "删除这条摘记？",
            isPresented: Binding(
                get: { deletingText != nil },
                set: { if !$0 { deletingText = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let deletingText {
                    delete(deletingText)
                }
                deletingText = nil
            }
            Button("取消", role: .cancel) {
                deletingText = nil
            }
        }
        .animation(AppTheme.contentAnimation, value: book.status)
        .animation(AppTheme.contentAnimation, value: book.startDate)
        .animation(AppTheme.contentAnimation, value: book.finishDate)
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
                    if book.startDate == nil {
                        book.startDate = sortedLogs.last?.date ?? Date()
                    }
                    if book.finishDate == nil {
                        book.finishDate = Date()
                    }
                }

                try? modelContext.save()
            }
        )
    }

    private var optionalStartDateBinding: Binding<Date?> {
        Binding(
            get: { book.startDate },
            set: { newDate in
                book.startDate = newDate
                try? modelContext.save()
            }
        )
    }

    private var optionalFinishDateBinding: Binding<Date?> {
        Binding(
            get: { book.finishDate },
            set: { newDate in
                book.finishDate = newDate
                try? modelContext.save()
            }
        )
    }

    private var dateRangeCaption: String {
        switch (book.startDate, book.finishDate) {
        case let (start?, finish?):
            "\(AppDateText.monthDay(start)) - \(AppDateText.monthDay(finish))"
        case let (start?, nil):
            "\(AppDateText.monthDay(start)) 开始"
        case let (nil, finish?):
            "\(AppDateText.monthDay(finish)) 结束"
        case (nil, nil):
            "未设置"
        }
    }

    private func delete(_ text: BookText) {
        modelContext.delete(text)
        try? modelContext.save()
    }
}

private struct BookDetailHero: View {
    let book: Book

    var body: some View {
        VStack(spacing: 12) {
            BookCover(book: book)
                .frame(width: 176)

            VStack(spacing: 5) {
                Text(book.title)
                    .font(.system(size: 28, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                Text(book.author.isEmpty ? "未填写作者" : book.author)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 12) {
                BookDetailHeroMetric(value: "\(book.readingDays)", label: "阅读天数")
                BookDetailHeroMetric(value: "\(book.totalReadingMinutes)", label: "阅读时长")
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }
}

private struct BookDetailHeroMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 82)
    }
}

private struct OptionalBookDateRow: View {
    let title: String
    @Binding var date: Date?
    let fallbackDate: Date

    private var concreteDate: Binding<Date> {
        Binding(
            get: { date ?? fallbackDate },
            set: { date = $0 }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            if date == nil {
                Button("设置") {
                    date = fallbackDate
                }
                .font(.system(size: 14, weight: .semibold))
                .buttonStyle(.bordered)
                .tint(AppTheme.accent)
            } else {
                DatePicker("", selection: concreteDate, displayedComponents: [.date])
                    .labelsHidden()
                    .environment(\.locale, AppDateText.chineseLocale)

                Button {
                    date = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .accessibilityLabel("清除\(title)")
            }
        }
        .padding(.vertical, 9)
    }
}

private struct BookDetailReadingLogRow: View {
    let log: ReadingLog
    let pagesRead: Int?

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: log.date))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(AppDateText.month(log.date))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 48)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(pagesCaption)
                        .foregroundStyle(.primary)

                    Spacer(minLength: 10)

                    Text("\(log.minutes) 分钟")
                        .foregroundStyle(.primary)
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()

                Text(timeRangeCaption)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var pagesCaption: String {
        if let pagesRead {
            return "读了 \(pagesRead) 页"
        }
        return "未记录页数"
    }

    private var timeRangeCaption: String {
        let end = log.date
        let start = end.addingTimeInterval(TimeInterval(-log.minutes * 60))
        return "\(AppDateText.time(start))-\(AppDateText.time(end))"
    }
}

private struct BookDetailAllReadingLogsView: View {
    @Environment(\.modelContext) private var modelContext

    let book: Book

    @State private var editingLog: ReadingLog?
    @State private var deletingLog: ReadingLog?

    private var sortedLogs: [ReadingLog] {
        book.logs.sorted { $0.date > $1.date }
    }

    private var pagesReadByLogID: [UUID: Int] {
        ReadingLogMetrics.pagesReadByLogID(for: sortedLogs)
    }

    var body: some View {
        PageShell {
            if sortedLogs.isEmpty {
                AppEmptyState(
                    title: "暂无阅读记录",
                    message: "手动记录这本书的阅读时长。",
                    systemImage: "calendar"
                )
            } else {
                AppCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(sortedLogs) { log in
                            BookDetailReadingLogRow(log: log, pagesRead: pagesReadByLogID[log.id])
                                .contextMenu {
                                    Button {
                                        editingLog = log
                                    } label: {
                                        Label("编辑", systemImage: "pencil")
                                    }

                                    Button(role: .destructive) {
                                        deletingLog = log
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }

                            if log.id != sortedLogs.last?.id {
                                Divider()
                                    .padding(.leading, 76)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $editingLog) { log in
            AddReadingLogSheet(books: [book], preferredBookID: book.id, editingLog: log)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "删除这条阅读记录？",
            isPresented: Binding(
                get: { deletingLog != nil },
                set: { if !$0 { deletingLog = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let deletingLog {
                    delete(deletingLog)
                }
                deletingLog = nil
            }
            Button("取消", role: .cancel) {
                deletingLog = nil
            }
        }
    }

    private func delete(_ log: ReadingLog) {
        modelContext.delete(log)
        ReadingLogMetrics.refreshCurrentPage(for: book, excluding: log.id)
        try? modelContext.save()
    }
}

private struct BookDetailAllTextsView: View {
    @Environment(\.modelContext) private var modelContext

    let book: Book

    @State private var editingText: BookText?
    @State private var deletingText: BookText?

    private var sortedTexts: [BookText] {
        book.texts.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        PageShell {
            if sortedTexts.isEmpty {
                AppEmptyState(
                    title: "暂无摘记",
                    message: "保存书里的句子，或写下自己的想法。",
                    systemImage: "quote.opening"
                )
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(sortedTexts) { text in
                        AppCard {
                            BookTextRow(text: text, showsBookTitle: false)
                        }
                        .contextMenu {
                            Button {
                                editingText = text
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                deletingText = text
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $editingText) { text in
            AddBookTextSheet(books: [book], preferredBookID: book.id, editingText: text)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "删除这条摘记？",
            isPresented: Binding(
                get: { deletingText != nil },
                set: { if !$0 { deletingText = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let deletingText {
                    modelContext.delete(deletingText)
                    try? modelContext.save()
                }
                deletingText = nil
            }
            Button("取消", role: .cancel) {
                deletingText = nil
            }
        }
    }
}

private extension Book {
    var readingDays: Int {
        Set(logs.map { Calendar.current.startOfDay(for: $0.date) }).count
    }
}

#if DEBUG
#Preview("Book Detail") {
    PreviewHost { data in
        NavigationStack {
            if let book = data.books.first {
                BookDetailView(book: book)
            }
        }
    }
}
#endif
