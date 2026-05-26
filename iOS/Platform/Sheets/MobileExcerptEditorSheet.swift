#if os(iOS)
import SwiftData
import SwiftUI

private enum MobileExcerptFormField: Hashable {
    case title
    case source
    case sourceAuthor
    case relatedBook
}

private enum MobileExcerptInputMetrics {
    static let fieldFont = Font.system(size: 16, weight: .regular)
    static let contentFont = Font.system(size: 18, weight: .regular, design: .serif)
    static let fieldHorizontalPadding: CGFloat = 14
    static let fieldVerticalPadding: CGFloat = 12
    static let contentPadding: CGFloat = 13
    static let fieldCornerRadius: CGFloat = 12
    static let contentCornerRadius: CGFloat = 16
}

private struct MobileExcerptCategoryFormConfig {
    let heading: String
    let contentLabel: String
    let contentPlaceholder: String
    let fields: [MobileExcerptFormField]
    let requiredFields: Set<MobileExcerptFormField>

    func label(for field: MobileExcerptFormField) -> String {
        switch field {
        case .title: return "标题"
        case .source:
            switch heading {
            case "新增台词": return "出处"
            case "新增拾遗": return "来源"
            default: return "出处"
            }
        case .sourceAuthor:
            return heading == "新增台词" ? "角色" : "作者"
        case .relatedBook:
            return "关联书籍"
        }
    }

    func placeholder(for field: MobileExcerptFormField) -> String {
        switch field {
        case .title:
            switch heading {
            case "新增诗歌": return "例如：将进酒"
            case "新增词曲": return "例如：水调歌头"
            case "新增短文": return "例如：一段短文"
            default: return "例如：标题"
            }
        case .source:
            switch heading {
            case "新增台词": return "例如：星际穿越"
            case "新增拾遗": return "例如：网页、播客或文章"
            default: return "例如：书名、篇名或来源"
            }
        case .sourceAuthor:
            return heading == "新增台词" ? "例如：库珀" : "例如：李白"
        case .relatedBook:
            return ""
        }
    }
}

private extension ExcerptCategory {
    var mobileFormConfig: MobileExcerptCategoryFormConfig {
        switch self {
        case .bookExcerpt:
            return MobileExcerptCategoryFormConfig(
                heading: "新增书摘",
                contentLabel: "摘录正文",
                contentPlaceholder: "输入书中值得留下的句子...",
                fields: [.relatedBook],
                requiredFields: [.relatedBook]
            )
        case .note:
            return MobileExcerptCategoryFormConfig(
                heading: "新增笔记",
                contentLabel: "笔记正文",
                contentPlaceholder: "记录此刻的想法...",
                fields: [.relatedBook],
                requiredFields: []
            )
        case .poetry:
            return MobileExcerptCategoryFormConfig(
                heading: "新增诗歌",
                contentLabel: "诗歌正文",
                contentPlaceholder: "写下诗句，支持换行...",
                fields: [.title, .sourceAuthor, .source],
                requiredFields: [.title]
            )
        case .lyric:
            return MobileExcerptCategoryFormConfig(
                heading: "新增词曲",
                contentLabel: "词曲正文",
                contentPlaceholder: "写下歌词或词句...",
                fields: [.title, .sourceAuthor, .source],
                requiredFields: [.title]
            )
        case .prose:
            return MobileExcerptCategoryFormConfig(
                heading: "新增短文",
                contentLabel: "短文正文",
                contentPlaceholder: "写下一段短文...",
                fields: [.title, .sourceAuthor, .source],
                requiredFields: [.title]
            )
        case .quote:
            return MobileExcerptCategoryFormConfig(
                heading: "新增语录",
                contentLabel: "语录正文",
                contentPlaceholder: "输入一句值得保存的话...",
                fields: [.sourceAuthor, .source],
                requiredFields: []
            )
        case .web:
            return MobileExcerptCategoryFormConfig(
                heading: "新增拾遗",
                contentLabel: "内容正文",
                contentPlaceholder: "记录网页、播客、文章或偶然所得...",
                fields: [.source],
                requiredFields: []
            )
        case .movie:
            return MobileExcerptCategoryFormConfig(
                heading: "新增台词",
                contentLabel: "台词正文",
                contentPlaceholder: "输入台词，支持换行...",
                fields: [.source, .sourceAuthor],
                requiredFields: [.source]
            )
        }
    }
}

// MARK: - iOS 摘录录入弹窗

struct MobileExcerptEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
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

    private enum Field: Hashable {
        case content
        case title
        case sourceAuthor
        case source
    }

    private var isEdit: Bool { excerptToEdit != nil }
    private var config: MobileExcerptCategoryFormConfig { selectedCategory.mobileFormConfig }
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
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 22) {
                    categoryRail
                    dynamicFields
                    contentEditor
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.m)
                .padding(.bottom, AppSpacing.emptyState)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppColors.primaryBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle(isEdit ? "编辑摘录" : config.heading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        focusedField = nil
                        isPresented = false
                    }
                    .foregroundStyle(.secondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEdit ? "保存" : "完成") {
                        saveExcerpt()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }

            }
            .onAppear(perform: loadInitialValues)
            .onChange(of: selectedCategory) { _, _ in
                normalizeFieldsForCategory()
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var categoryRail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分类")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExcerptCategory.allCases, id: \.self) { category in
                        categoryButton(category)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func categoryButton(_ category: ExcerptCategory) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeOut(duration: 0.18)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: iconName(for: category))
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 14)

                Text(category.displayName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? AppColors.readingAmber : Color.primary.opacity(0.72))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .appCapsuleStyle(tint: isSelected ? AppColors.readingAmber : .secondary, fillOpacity: isSelected ? 0.14 : 0.10, strokeOpacity: isSelected ? 0 : 0.08)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var dynamicFields: some View {
        ForEach(config.fields, id: \.self) { field in
            fieldView(field)
        }
    }

    @ViewBuilder
    private func fieldView(_ field: MobileExcerptFormField) -> some View {
        switch field {
        case .relatedBook:
            relatedBookPicker
        case .title:
            inputField(
                label: config.label(for: field),
                placeholder: config.placeholder(for: field),
                text: $titleInput,
                focus: .title,
                isRequired: config.requiredFields.contains(field)
            )
        case .sourceAuthor:
            inputField(
                label: config.label(for: field),
                placeholder: config.placeholder(for: field),
                text: $sourceAuthorInput,
                focus: .sourceAuthor,
                isRequired: config.requiredFields.contains(field)
            )
        case .source:
            inputField(
                label: config.label(for: field),
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
                HStack(spacing: 11) {
                    selectedBookCover

                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedBookTitle)
                            .font(MobileExcerptInputMetrics.fieldFont)
                            .foregroundStyle(selectedBookID.isEmpty ? .secondary : .primary)
                            .lineLimit(1)

                        if let author = selectedBookAuthor {
                            Text(author)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, MobileExcerptInputMetrics.fieldHorizontalPadding)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                .background(fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: MobileExcerptInputMetrics.fieldCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)

            if allBooks.isEmpty && config.requiredFields.contains(.relatedBook) {
                Text("请先添加一本书，再录入书摘。")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var selectedBookCover: some View {
        if let selectedBook {
            BookCoverView(
                coverID: selectedBook.id,
                coverData: selectedBook.coverData,
                fallbackTitle: selectedBook.title
            )
            .frame(width: 34, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(AppColors.readingAmber.opacity(0.12))
                .frame(width: 34, height: 48)
                .overlay {
                    Image(systemName: "book.closed")
                        .font(.system(size: 14, weight: .medium))
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
                .submitLabel(.done)
                .focused($focusedField, equals: focus)
                .font(MobileExcerptInputMetrics.fieldFont)
                .padding(.horizontal, MobileExcerptInputMetrics.fieldHorizontalPadding)
                .padding(.vertical, MobileExcerptInputMetrics.fieldVerticalPadding)
                .background(fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: MobileExcerptInputMetrics.fieldCornerRadius, style: .continuous))
                .onSubmit { focusedField = nil }
        }
    }

    private var contentEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            fieldCaption(config.contentLabel, isRequired: true)

            ZStack(alignment: .topLeading) {
                if contentInput.isEmpty {
                    Text(config.contentPlaceholder)
                        .foregroundStyle(.secondary.opacity(0.55))
                        .font(MobileExcerptInputMetrics.contentFont)
                        .lineSpacing(5)
                        .padding(MobileExcerptInputMetrics.contentPadding)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $contentInput)
                    .font(MobileExcerptInputMetrics.contentFont)
                    .lineSpacing(5)
                    .focused($focusedField, equals: .content)
                    .scrollContentBackground(.hidden)
                    .padding(MobileExcerptInputMetrics.contentPadding)
            }
            .frame(minHeight: 240, alignment: .top)
            .background(fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: MobileExcerptInputMetrics.contentCornerRadius, style: .continuous))
        }
    }

    private var fieldBackground: some ShapeStyle {
        AppColors.innerBlock(for: colorScheme)
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            focusedField = .content
        }
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

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

        focusedField = nil
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
}

#if DEBUG
#Preview("摘录录入弹窗") {
    PreviewWithData {
        PreviewSheet {
            MobileExcerptEditorSheet(isPresented: .constant(true))
        }
    }
}
#endif
#endif
