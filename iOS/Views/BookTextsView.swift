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
    let texts: [BookText]
    let onAddText: () -> Void

    @State private var searchText = ""
    @State private var filter: TextFilter = .all

    private var excerpts: [BookText] { texts.filter { $0.kind == .excerpt } }
    private var notes: [BookText] { texts.filter { $0.kind == .note } }

    private var visibleTexts: [BookText] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return texts.filter { text in
            let matchesKind = filter.kind.map { text.kind == $0 } ?? true
            let matchesQuery = query.isEmpty
                || text.content.localizedStandardContains(query)
                || (text.book?.title.localizedStandardContains(query) ?? false)
                || (text.book?.author.localizedStandardContains(query) ?? false)
            return matchesKind && matchesQuery
        }
    }

    var body: some View {
        PageShell {
            AppCard {
                HStack(spacing: 18) {
                    FactPill(value: "\(excerpts.count)", label: "摘录")
                    FactPill(value: "\(notes.count)", label: "笔记")
                    FactPill(value: "\(texts.count)", label: "合计")
                }
            }

            Picker("类型", selection: $filter) {
                ForEach(TextFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 2)

            if texts.isEmpty {
                AppCard {
                    EmptyHint(
                        title: "暂无摘记",
                        message: "从一本书开始，保存值得留下的句子或自己的想法。",
                        systemImage: "quote.opening"
                    )
                    PrimaryActionButton(title: "添加摘记", systemImage: "plus", action: onAddText)
                }
            } else if visibleTexts.isEmpty {
                AppCard {
                    EmptyHint(title: "没有找到内容", message: "换一个关键词或类型试试。", systemImage: "magnifyingglass")
                }
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(visibleTexts) { text in
                        if let book = text.book {
                            NavigationLink {
                                BookDetailView(book: book)
                            } label: {
                                AppCard {
                                    BookTextRow(text: text)
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
                            AppCard {
                                BookTextRow(text: text)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("摘记")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "搜索正文、书名、作者")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAddText) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("添加摘记")
            }
        }
        .animation(AppTheme.contentAnimation, value: visibleTexts.map(\.id))
        .animation(AppTheme.controlAnimation, value: filter)
    }
}

struct BookTextRow: View {
    let text: BookText

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                KindBadge(kind: text.kind)

                Spacer(minLength: 16)

                if let title = text.book?.title {
                    Text("《\(title)》")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Text(text.content)
                .font(.system(size: 17, weight: .regular))
                .lineSpacing(5)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text(text.createdAt.formatted(date: .abbreviated, time: .omitted))
                if text.page > 0 {
                    Text("第 \(text.page) 页")
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.tertiary)
        }
    }
}
