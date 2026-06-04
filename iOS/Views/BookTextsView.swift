import SwiftData
import SwiftUI

private enum TextFilter: String, CaseIterable, Identifiable {
    case all
    case excerpt
    case note

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .excerpt: "摘录"
        case .note: "笔记"
        }
    }

    var kind: BookTextKind? {
        switch self {
        case .all: nil
        case .excerpt: .excerpt
        case .note: .note
        }
    }
}

struct BookTextsView: View {
    @Environment(\.modelContext) private var modelContext

    let books: [Book]
    let texts: [BookText]

    @State private var filter: TextFilter = .all
    @State private var editingText: BookText?
    @State private var deletingText: BookText?

    private var excerpts: [BookText] { texts.filter { $0.kind == .excerpt } }
    private var notes: [BookText] { texts.filter { $0.kind == .note } }

    private var visibleTexts: [BookText] {
        return texts
            .filter { text in
                filter.kind.map { text.kind == $0 } ?? true
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        PageShell {
            HStack(spacing: 10) {
                MetricValue(value: excerpts.count, label: "摘录")
                MetricValue(value: notes.count, label: "笔记")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)

            Picker("类型", selection: $filter) {
                ForEach(TextFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 2)

            if texts.isEmpty {
                AppEmptyState(
                    title: "暂无摘记",
                    message: "保存书里的句子，或写下自己的想法。",
                    systemImage: "quote.opening"
                )
            } else if visibleTexts.isEmpty {
                AppEmptyState(
                    title: "暂无\(filter.title)",
                    message: "当前类型下还没有内容。",
                    systemImage: "quote.opening",
                    style: .compact
                )
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(visibleTexts) { text in
                        if let book = text.book {
                            NavigationLink {
                                BookDetailView(book: book)
                            } label: {
                                textCard(text)
                            }
                            .buttonStyle(.plain)
                        } else {
                            textCard(text)
                        }
                    }
                }
            }
        }
        .sheet(item: $editingText) { text in
            AddBookTextSheet(books: books, editingText: text)
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
                    delete(deletingText)
                }
                deletingText = nil
            }
            Button("取消", role: .cancel) {
                deletingText = nil
            }
        }
        .animation(.easeInOut(duration: 0.18), value: filter)
    }

    private func textCard(_ text: BookText) -> some View {
        AppCard {
            BookTextRow(text: text)
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

    private func delete(_ text: BookText) {
        modelContext.delete(text)
        try? modelContext.save()
    }
}

struct BookTextRow: View {
    let text: BookText
    var showsBookTitle = true

    private var metadataText: String {
        if text.page > 0 {
            return "\(AppDateText.monthDay(text.createdAt)) · 第 \(text.page) 页"
        }
        return AppDateText.monthDay(text.createdAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                if showsBookTitle, let title = text.book?.title {
                    Text("《\(title)》")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(metadataText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 16)

                KindBadge(kind: text.kind)
            }

            Text(text.content)
                .font(.system(size: 17, weight: .regular))
                .lineSpacing(6)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if showsBookTitle {
                HStack(spacing: 8) {
                    Text(AppDateText.monthDay(text.createdAt))
                    if text.page > 0 {
                        Text("· 第 \(text.page) 页")
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
            }
        }
    }
}

#if DEBUG
#Preview("Book Texts") {
    PreviewHost { data in
        NavigationStack {
            BookTextsView(books: data.books, texts: data.texts)
        }
    }
}

#Preview("Book Texts Empty") {
    NavigationStack {
        BookTextsView(books: [], texts: [])
    }
    .modelContainer(PreviewData.emptyContainer())
}
#endif
