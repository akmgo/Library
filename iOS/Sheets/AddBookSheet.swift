import SwiftData
import SwiftUI

struct AddBookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var title = ""
    @State private var author = ""
    @State private var publisher = ""
    @State private var totalPages = 0
    @State private var status: BookStatus = .planned
    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case author
        case publisher
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("书名", text: $title)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                    TextField("作者", text: $author)
                        .focused($focusedField, equals: .author)
                        .submitLabel(.next)
                    TextField("出版社", text: $publisher)
                        .focused($focusedField, equals: .publisher)
                        .submitLabel(.done)
                } header: {
                    Text("基础信息")
                }

                Section {
                    Picker("状态", selection: $status) {
                        ForEach(BookStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    Stepper(value: $totalPages, in: 0...5000, step: 10) {
                        LabeledContent("总页数") {
                            Text(totalPages > 0 ? "\(totalPages) 页" : "未设置")
                                .foregroundStyle(AppTheme.secondaryText(colorScheme))
                                .contentTransition(.numericText())
                        }
                    }
                } header: {
                    Text("阅读信息")
                } footer: {
                    Text("页数可稍后在书籍详情中补充或修改。")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background(colorScheme))
            .tint(AppTheme.accent)
            .navigationTitle("新书")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                focusedField = .title
            }
            .onSubmit {
                advanceFocus()
            }
            .animation(AppTheme.controlAnimation, value: totalPages)
        }
    }

    private func advanceFocus() {
        switch focusedField {
        case .title:
            focusedField = .author
        case .author:
            focusedField = .publisher
        default:
            focusedField = nil
        }
    }

    private func save() {
        let book = Book(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
            publisher: publisher.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status,
            totalPages: totalPages
        )
        modelContext.insert(book)
        try? modelContext.save()
        dismiss()
    }
}
