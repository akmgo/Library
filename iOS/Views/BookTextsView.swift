import SwiftUI

struct BookTextsView: View {
    let texts: [BookText]
    let onAddText: () -> Void

    private var excerpts: [BookText] { texts.filter { $0.kind == .excerpt } }
    private var notes: [BookText] { texts.filter { $0.kind == .note } }

    var body: some View {
        PageShell(title: "摘录", subtitle: "只保存书摘和笔记") {
            AppCard {
                HStack {
                    MetricBlock(value: "\(excerpts.count)", label: "书摘")
                    Spacer()
                    MetricBlock(value: "\(notes.count)", label: "笔记")
                    Spacer()
                    MetricBlock(value: "\(texts.count)", label: "合计")
                }
            }

            if texts.isEmpty {
                AppCard {
                    EmptyHint(title: "暂无内容", message: "选择一本书，留下值得保存的句子或想法。")
                    Button(action: onAddText) {
                        Label("添加摘录", systemImage: "quote.opening")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(texts) { text in
                        AppCard {
                            BookTextRow(text: text)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAddText) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct BookTextRow: View {
    let text: BookText

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(text.kind.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.accent.opacity(0.12), in: Capsule())

                Spacer()

                if let title = text.book?.title {
                    Text("《\(title)》")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Text(text.content)
                .font(.system(size: 17))
                .lineSpacing(5)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(text.createdAt.formatted(date: .abbreviated, time: .omitted))
                if text.page > 0 {
                    Text("第 \(text.page) 页")
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
        }
    }
}

private struct MetricBlock: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
