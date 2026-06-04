import SwiftData
import SwiftUI

struct AddBookTextSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    let books: [Book]
    var preferredBookID: UUID?

    @State private var selectedBookID: UUID?
    @State private var kind: BookTextKind = .excerpt
    @State private var content = ""
    @State private var page = 0
    @FocusState private var contentFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                if books.isEmpty {
                    Section {
                        EmptyHint(
                            title: "还没有书",
                            message: "摘录和笔记需要先关联一本书。",
                            systemImage: "quote.opening"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    }
                } else {
                    Section {
                        Picker("类型", selection: $kind) {
                            ForEach(BookTextKind.allCases) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section {
                        Picker("书籍", selection: $selectedBookID) {
                            ForEach(books) { book in
                                Text(book.title).tag(Optional(book.id))
                            }
                        }
                    }

                    Section {
                        ZStack(alignment: .topLeading) {
                            if content.isEmpty {
                                Text(kind == .excerpt ? "输入书中值得留下的句子" : "输入这本书带来的想法")
                                    .foregroundStyle(AppTheme.tertiaryText(colorScheme))
                                    .padding(.top, 8)
                                    .padding(.horizontal, 5)
                                    .allowsHitTesting(false)
                            }

                            TextEditor(text: $content)
                                .focused($contentFocused)
                                .frame(minHeight: 190)
                                .scrollContentBackground(.hidden)
                        }

                        Stepper(value: $page, in: 0...5000) {
                            LabeledContent("页码") {
                                Text(page > 0 ? "第 \(page) 页" : "不记录")
                                    .foregroundStyle(AppTheme.secondaryText(colorScheme))
                                    .contentTransition(.numericText())
                            }
                        }
                    } header: {
                        Text(kind == .excerpt ? "书摘" : "笔记")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background(colorScheme))
            .tint(AppTheme.accent)
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(selectedBook == nil || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if selectedBookID == nil {
                    selectedBookID = preferredBookID ?? books.first?.id
                }
                contentFocused = !books.isEmpty
            }
            .animation(AppTheme.controlAnimation, value: kind)
            .animation(AppTheme.controlAnimation, value: page)
        }
    }

    private var selectedBook: Book? {
        books.first { $0.id == selectedBookID }
    }

    private func save() {
        guard let selectedBook else { return }
        let text = BookText(
            book: selectedBook,
            kind: kind,
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            page: page
        )
        selectedBook.texts.append(text)
        modelContext.insert(text)
        try? modelContext.save()
        dismiss()
    }
}
