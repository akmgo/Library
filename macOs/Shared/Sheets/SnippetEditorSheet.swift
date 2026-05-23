#if os(macOS)
import SwiftData
import SwiftUI

private enum ExcerptFormField: Hashable {
    case title
    case source
    case sourceAuthor
    case relatedBook
}

private enum ExcerptInputMetrics {
    static let fieldFont = Font.system(size: 16, weight: .regular)
    static let contentFont = Font.system(size: 18, weight: .regular, design: .serif)
    static let fieldHorizontalPadding: CGFloat = 14
    static let fieldVerticalPadding: CGFloat = 12
    static let contentPadding: CGFloat = 13
    static let fieldCornerRadius: CGFloat = 8
    static let contentCornerRadius: CGFloat = 8
}

private struct ExcerptCategoryFormConfig {
    let heading: String
    let contentLabel: String
    let contentPlaceholder: String
    let fields: [ExcerptFormField]
    let requiredFields: Set<ExcerptFormField>

    func label(for field: ExcerptFormField) -> String {
        switch field {
        case .title:
            return titleLabel
        case .source:
            return sourceLabel
        case .sourceAuthor:
            return sourceAuthorLabel
        case .relatedBook:
            return "关联书籍"
        }
    }

    func placeholder(for field: ExcerptFormField) -> String {
        switch field {
        case .title:
            return titlePlaceholder
        case .source:
            return sourcePlaceholder
        case .sourceAuthor:
            return sourceAuthorPlaceholder
        case .relatedBook:
            return ""
        }
    }

    private var titleLabel: String { "标题" }

    private var titlePlaceholder: String {
        switch heading {
        case "新增诗歌": return "例如：将进酒"
        case "新增词曲": return "例如：水调歌头"
        case "新增短文": return "例如：一段短文"
        default: return "例如：标题"
        }
    }

    private var sourceLabel: String {
        switch heading {
        case "新增台词": return "出处"
        case "新增拾遗": return "来源"
        default: return "出处"
        }
    }

    private var sourcePlaceholder: String {
        switch heading {
        case "新增台词": return "例如：星际穿越"
        case "新增拾遗": return "例如：网页、播客或文章"
        default: return "例如：书名、篇名或来源"
        }
    }

    private var sourceAuthorLabel: String {
        switch heading {
        case "新增台词": return "角色"
        default: return "作者"
        }
    }

    private var sourceAuthorPlaceholder: String {
        switch heading {
        case "新增台词": return "例如：库珀"
        default: return "例如：李白"
        }
    }
}

private extension ExcerptCategory {
    var formConfig: ExcerptCategoryFormConfig {
        switch self {
        case .bookExcerpt:
            return ExcerptCategoryFormConfig(
                heading: "新增书摘",
                contentLabel: "摘录正文",
                contentPlaceholder: "输入书中值得留下的句子...",
                fields: [.relatedBook],
                requiredFields: [.relatedBook]
            )
        case .note:
            return ExcerptCategoryFormConfig(
                heading: "新增笔记",
                contentLabel: "笔记正文",
                contentPlaceholder: "记录此刻的想法...",
                fields: [.relatedBook],
                requiredFields: []
            )
        case .poetry:
            return ExcerptCategoryFormConfig(
                heading: "新增诗歌",
                contentLabel: "诗歌正文",
                contentPlaceholder: "写下诗句，支持换行...",
                fields: [.title, .sourceAuthor, .source],
                requiredFields: [.title]
            )
        case .lyric:
            return ExcerptCategoryFormConfig(
                heading: "新增词曲",
                contentLabel: "词曲正文",
                contentPlaceholder: "写下歌词或词句...",
                fields: [.title, .sourceAuthor, .source],
                requiredFields: [.title]
            )
        case .prose:
            return ExcerptCategoryFormConfig(
                heading: "新增短文",
                contentLabel: "短文正文",
                contentPlaceholder: "写下一段短文...",
                fields: [.title, .sourceAuthor, .source],
                requiredFields: [.title]
            )
        case .quote:
            return ExcerptCategoryFormConfig(
                heading: "新增语录",
                contentLabel: "语录正文",
                contentPlaceholder: "输入一句值得保存的话...",
                fields: [.sourceAuthor, .source],
                requiredFields: []
            )
        case .web:
            return ExcerptCategoryFormConfig(
                heading: "新增拾遗",
                contentLabel: "内容正文",
                contentPlaceholder: "记录网页、播客、文章或偶然所得...",
                fields: [.source],
                requiredFields: []
            )
        case .movie:
            return ExcerptCategoryFormConfig(
                heading: "新增台词",
                contentLabel: "台词正文",
                contentPlaceholder: "输入台词，支持换行...",
                fields: [.source, .sourceAuthor],
                requiredFields: [.source]
            )
        }
    }
}

struct ExcerptEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.createdAt, order: .reverse) private var allBooks: [Book]

    @Binding var isPresented: Bool
    var excerptToEdit: Excerpt? = nil

    @State private var selectedCategory: ExcerptCategory = .web
    @State private var selectedBookID: String = ""
    @State private var titleInput: String = ""
    @State private var contentInput: String = ""
    @State private var sourceAuthorInput: String = ""
    @State private var sourceInput: String = ""

    @FocusState private var focusedField: Field?

    private enum Field {
        case content
        case title
        case sourceAuthor
        case source
    }

    private var isEdit: Bool { excerptToEdit != nil }
    private var config: ExcerptCategoryFormConfig { selectedCategory.formConfig }
    private var trimmedContent: String { contentInput.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedTitle: String { titleInput.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedSourceAuthor: String { sourceAuthorInput.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedSource: String { sourceInput.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var selectedBook: Book? { allBooks.first(where: { $0.id == selectedBookID }) }

    private var selectedBookTitle: String {
        if let selectedBook { return selectedBook.title }
        return config.requiredFields.contains(.relatedBook) ? "选择一本书" : "不关联书籍"
    }

    private var selectedBookAuthor: String? {
        guard let author = selectedBook?.author.trimmingCharacters(in: .whitespacesAndNewlines), !author.isEmpty else {
            return nil
        }
        return author
    }

    private var canSave: Bool {
        guard !trimmedContent.isEmpty else { return false }
        if config.requiredFields.contains(.title), trimmedTitle.isEmpty { return false }
        if config.requiredFields.contains(.source), trimmedSource.isEmpty { return false }
        if config.requiredFields.contains(.sourceAuthor), trimmedSourceAuthor.isEmpty { return false }
        if config.requiredFields.contains(.relatedBook), selectedBookID.isEmpty { return false }
        return true
    }

    var body: some View {
        HStack(spacing: 0) {
            categorySidebar

            Divider().opacity(0.45)

            VStack(spacing: 0) {
                sheetHeader

                Divider().opacity(0.45)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        dynamicFields
                        contentEditor
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 26)
                }

                Divider().opacity(0.45)

                sheetFooter
            }
        }
        .frame(width: 760, height: 620)
        .glassEffect(in: .rect(cornerRadius: 16))
        .background(WindowTransparentEffect())
        .onAppear(perform: loadInitialValues)
        .onChange(of: selectedCategory) { _, _ in
            normalizeFieldsForCategory()
        }
    }

    private var categorySidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分类")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 18)
                .padding(.bottom, 4)

            ForEach(ExcerptCategory.allCases, id: \.self) { category in
                categoryButton(category)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
        .frame(width: 122)
        .background(Color.primary.opacity(0.025))
    }

    private func categoryButton(_ category: ExcerptCategory) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            withAnimation(.appContentFade) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: iconName(for: category))
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 17)

                Text(category.displayName)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))

                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? AppColors.readingAmber : Color.primary.opacity(0.72))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? AppColors.readingAmber.opacity(0.14) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(keyEquivalent(for: category), modifiers: .command)
    }

    private var sheetHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: isEdit ? "text.quote" : "square.and.pencil")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(AppColors.readingAmber)

            VStack(alignment: .leading, spacing: 5) {
                Text(isEdit ? "编辑摘录" : config.heading)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }

            Spacer()
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 22)
    }

    @ViewBuilder
    private var dynamicFields: some View {
        let rows = fieldRows(from: config.fields)

        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
            HStack(alignment: .top, spacing: 18) {
                ForEach(row, id: \.self) { field in
                    fieldView(field)
                }
            }
        }
    }

    private func fieldRows(from fields: [ExcerptFormField]) -> [[ExcerptFormField]] {
        var rows: [[ExcerptFormField]] = []
        var current: [ExcerptFormField] = []

        for field in fields {
            if field == .relatedBook || current.count == 2 {
                if !current.isEmpty {
                    rows.append(current)
                    current = []
                }
            }

            current.append(field)

            if field == .relatedBook {
                rows.append(current)
                current = []
            }
        }

        if !current.isEmpty {
            rows.append(current)
        }

        return rows
    }

    @ViewBuilder
    private func fieldView(_ field: ExcerptFormField) -> some View {
        switch field {
        case .relatedBook:
            relatedBookPicker
        case .title:
            inputField(
                label: fieldLabel(field),
                placeholder: config.placeholder(for: field),
                text: $titleInput,
                focus: .title,
                isRequired: config.requiredFields.contains(field)
            )
        case .sourceAuthor:
            inputField(
                label: fieldLabel(field),
                placeholder: config.placeholder(for: field),
                text: $sourceAuthorInput,
                focus: .sourceAuthor,
                isRequired: config.requiredFields.contains(field)
            )
        case .source:
            inputField(
                label: fieldLabel(field),
                placeholder: config.placeholder(for: field),
                text: $sourceInput,
                focus: .source,
                isRequired: config.requiredFields.contains(field)
            )
        }
    }

    private var relatedBookPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            fieldCaption("关联书籍", isRequired: config.requiredFields.contains(.relatedBook))

            Menu {
                if !config.requiredFields.contains(.relatedBook) {
                    Button("不关联书籍") {
                        selectedBookID = ""
                    }
                }

                ForEach(allBooks) { book in
                    Button(book.title) {
                        selectedBookID = book.id
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    selectedBookCover

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedBookTitle)
                            .font(ExcerptInputMetrics.fieldFont)
                            .foregroundStyle(selectedBookID.isEmpty ? .secondary : .primary)
                            .lineLimit(1)

                        if let author = selectedBookAuthor {
                            Text(author)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, ExcerptInputMetrics.fieldHorizontalPadding)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: ExcerptInputMetrics.fieldCornerRadius))
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)

            if allBooks.isEmpty && config.requiredFields.contains(.relatedBook) {
                Text("请先添加一本书，再录入书摘。")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var selectedBookCover: some View {
        if let selectedBook {
            BookCoverView(
                coverID: selectedBook.id,
                coverData: selectedBook.coverData,
                fallbackTitle: selectedBook.title
            )
            .frame(width: 30, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        } else {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(AppColors.readingAmber.opacity(0.12))
                .frame(width: 30, height: 42)
                .overlay {
                    Image(systemName: "book.closed")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.readingAmber)
                }
        }
    }

    private func inputField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        focus: Field,
        isRequired: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            fieldCaption(label, isRequired: isRequired)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: focus)
                .font(ExcerptInputMetrics.fieldFont)
                .padding(.horizontal, ExcerptInputMetrics.fieldHorizontalPadding)
                .padding(.vertical, ExcerptInputMetrics.fieldVerticalPadding)
                .glassEffect(in: .rect(cornerRadius: ExcerptInputMetrics.fieldCornerRadius))
        }
        .frame(maxWidth: .infinity)
    }

    private var contentEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            fieldCaption(config.contentLabel, isRequired: true)

            ZStack(alignment: .topLeading) {
                if contentInput.isEmpty {
                    Text(config.contentPlaceholder)
                        .foregroundStyle(.secondary.opacity(0.55))
                        .font(ExcerptInputMetrics.contentFont)
                        .lineSpacing(5)
                        .padding(ExcerptInputMetrics.contentPadding)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $contentInput)
                    .font(ExcerptInputMetrics.contentFont)
                    .lineSpacing(5)
                    .focused($focusedField, equals: .content)
                    .scrollContentBackground(.hidden)
                    .padding(ExcerptInputMetrics.contentPadding)
            }
            .frame(minHeight: 230, alignment: .top)
            .glassEffect(in: .rect(cornerRadius: ExcerptInputMetrics.contentCornerRadius))
        }
    }

    private func fieldCaption(_ text: String, isRequired: Bool) -> some View {
        HStack(spacing: 4) {
            Text(text)
            if isRequired {
                Text("必填")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.readingAmber)
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
    }

    private func fieldLabel(_ field: ExcerptFormField) -> String {
        config.label(for: field)
    }

    private var sheetFooter: some View {
        HStack(spacing: 12) {
            Text(saveHint)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Button("取消") {
                isPresented = false
            }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(.plain)
            .font(.system(size: 15, weight: .medium))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))

            Button(isEdit ? "保存修改" : "确认录入") {
                saveExcerpt()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.plain)
            .disabled(!canSave)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(canSave ? Color.primary : Color.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .glassEffect(canSave ? .regular.tint(selectedCategory.themeColor).interactive() : .clear.interactive(), in: .rect(cornerRadius: 8))
            .opacity(canSave ? 1 : 0.42)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var saveHint: String {
        if trimmedContent.isEmpty { return "正文为必填项" }
        if config.requiredFields.contains(.relatedBook), selectedBookID.isEmpty { return "书摘需要关联书籍" }
        if config.requiredFields.contains(.title), trimmedTitle.isEmpty { return "标题为必填项" }
        if config.requiredFields.contains(.source), trimmedSource.isEmpty { return "出处为必填项" }
        return "Enter 保存，Esc 取消"
    }

    private func loadInitialValues() {
        if let excerpt = excerptToEdit {
            selectedCategory = excerpt.category
            selectedBookID = excerpt.book?.id ?? ""
            titleInput = excerpt.title ?? ""
            contentInput = excerpt.content
            sourceAuthorInput = excerpt.sourceAuthor ?? ""
            sourceInput = excerpt.source ?? ""
        } else if selectedCategory == .bookExcerpt, selectedBookID.isEmpty {
            selectedBookID = allBooks.first?.id ?? ""
        }

        focusedField = .content
    }

    private func normalizeFieldsForCategory() {
        let fields = Set(config.fields)

        if selectedCategory == .bookExcerpt, selectedBookID.isEmpty {
            selectedBookID = allBooks.first?.id ?? ""
        } else if !fields.contains(.relatedBook) {
            selectedBookID = ""
        }

        if !fields.contains(.sourceAuthor) {
            sourceAuthorInput = ""
        }
        if !fields.contains(.source) {
            sourceInput = ""
        }
        if !fields.contains(.title) {
            titleInput = ""
        }
    }

    private func saveExcerpt() {
        guard canSave else { return }

        let relatedBook = allBooks.first(where: { $0.id == selectedBookID })

        if let excerpt = excerptToEdit {
            excerpt.category = selectedCategory
            excerpt.title = trimmedTitle.isEmpty ? nil : trimmedTitle
            excerpt.content = trimmedContent
            excerpt.sourceAuthor = trimmedSourceAuthor.isEmpty ? nil : trimmedSourceAuthor
            excerpt.source = trimmedSource.isEmpty ? nil : trimmedSource
            excerpt.book = relatedBook
            try? modelContext.save()
        } else {
            let newExcerpt = Excerpt(
                content: trimmedContent,
                category: selectedCategory,
                title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                sourceAuthor: trimmedSourceAuthor.isEmpty ? nil : trimmedSourceAuthor,
                source: trimmedSource.isEmpty ? nil : trimmedSource,
                book: relatedBook
            )
            try? ReadingDataService.shared.insertExcerpt(newExcerpt, context: modelContext)
        }

        isPresented = false
    }

    private func iconName(for category: ExcerptCategory) -> String {
        switch category {
        case .bookExcerpt: return "text.quote"
        case .note: return "note.text"
        case .poetry: return "sparkles"
        case .lyric: return "music.note"
        case .prose: return "text.alignleft"
        case .quote: return "quote.opening"
        case .web: return "link"
        case .movie: return "film"
        }
    }

    private func keyEquivalent(for category: ExcerptCategory) -> KeyEquivalent {
        switch category {
        case .bookExcerpt: return "1"
        case .note: return "2"
        case .poetry: return "3"
        case .lyric: return "4"
        case .prose: return "5"
        case .quote: return "6"
        case .web: return "7"
        case .movie: return "8"
        }
    }
}

#Preview("摘录录入弹窗") {
    let schema = Schema([Book.self, Excerpt.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])

    ExcerptEditorSheet(isPresented: .constant(true))
        .padding(60)
        .background(AppColors.primaryBackground(for: .light))
        .modelContainer(container)
}
#endif
