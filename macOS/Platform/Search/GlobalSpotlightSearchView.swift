#if os(macOS)
import SwiftData
import SwiftUI

struct GlobalSpotlightSearchView: View {
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @Query(sort: \Excerpt.createdAt, order: .reverse) private var excerpts: [Excerpt]
    @Environment(\.colorScheme) private var colorScheme

    @Binding var isPresented: Bool
    @Binding var selectedModule: NavigationModule?
    @Binding var selectedBook: Book?
    @Binding var highlightedExcerptID: String?

    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var hasEntered = false
    @State private var isClosing = false
    @FocusState private var isFocused: Bool

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var bookResults: [GlobalSpotlightResult] {
        guard !trimmedQuery.isEmpty else { return [] }
        let query = trimmedQuery
        return books.filter { book in
            SearchMatcher.matchesBook(book, query: query)
        }.prefix(6).map(GlobalSpotlightResult.book)
    }

    private var excerptResults: [GlobalSpotlightResult] {
        guard !trimmedQuery.isEmpty else { return [] }
        let query = trimmedQuery
        return excerpts.filter { excerpt in
            SearchMatcher.matchesExcerpt(excerpt, query: query)
        }.prefix(8).map(GlobalSpotlightResult.excerpt)
    }

    private var allResults: [GlobalSpotlightResult] {
        bookResults + excerptResults
    }

    private var selectedResult: GlobalSpotlightResult? {
        guard allResults.indices.contains(selectedIndex) else { return nil }
        return allResults[selectedIndex]
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(colorScheme == .dark ? 0.24 : 0.10)
                .ignoresSafeArea()
                .onTapGesture { close() }
                .opacity(hasEntered ? 1 : 0)

            VStack(spacing: 0) {
                searchField

                if trimmedQuery.isEmpty {
                    emptyPrompt("搜索书籍和摘录")
                } else if allResults.isEmpty {
                    emptyPrompt("没有找到相关内容")
                } else {
                    Divider().opacity(0.24).padding(.horizontal, AppSpacing.m)
                    ScrollView(.vertical, showsIndicators: allResults.count > 5) {
                        LazyVStack(spacing: AppSpacing.l) {
                            if !bookResults.isEmpty {
                                resultSectionHeader(title: "书籍档案", count: bookResults.count)
                                ForEach(bookResults) { result in
                                    GlobalSpotlightResultCard(
                                        result: result,
                                        isSelected: result.id == selectedResult?.id
                                    ) {
                                        open(result)
                                    }
                                }
                            }

                            if !excerptResults.isEmpty {
                                resultSectionHeader(title: "摘录笔记", count: excerptResults.count)
                                ForEach(excerptResults) { result in
                                    GlobalSpotlightResultCard(
                                        result: result,
                                        isSelected: result.id == selectedResult?.id
                                    ) {
                                        open(result)
                                    }
                                }
                            }
                        }
                        .padding(AppSpacing.s)
                    }
                    .frame(maxHeight: 560)
                    .transition(.opacity)
                }
            }
            .frame(width: 700)
            .background(Color(nsColor: .windowBackgroundColor), in: .rect(cornerRadius: AppRadius.panel))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous)
                    .stroke(.primary.opacity(colorScheme == .dark ? 0.10 : 0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.12), radius: 32, y: 18)
            .padding(.top, 112)
            .scaleEffect(isClosing ? 0.98 : (hasEntered ? 1 : 0.98), anchor: .top)
            .opacity(hasEntered && !isClosing ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.18), value: hasEntered)
        .animation(.easeOut(duration: 0.16), value: isClosing)
        .animation(.easeOut(duration: 0.18), value: allResults.count)
        .onAppear {
            hasEntered = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                isFocused = true
            }
        }
        .onChange(of: query) { _, _ in selectedIndex = 0 }
        .background(shortcuts)
    }

    private var searchField: some View {
        HStack(spacing: AppSpacing.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppColors.readingAmber)
                .frame(width: 36)

            TextField("搜索书籍和摘录", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 26, weight: .medium))
                .focused($isFocused)
                .onSubmit { openSelected() }
        }
        .padding(.horizontal, AppSpacing.l)
        .frame(height: 80)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }

    private func resultSectionHeader(title: String, count: Int) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("(\(count))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.top, 4)
    }

    private func emptyPrompt(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xl)
    }

    private var shortcuts: some View {
        Group {
            Button("") { close() }
                .keyboardShortcut(.cancelAction)
            Button("") { openSelected() }
                .keyboardShortcut(.return)
            Button("") { moveSelection(1) }
                .keyboardShortcut(.downArrow, modifiers: [])
            Button("") { moveSelection(-1) }
                .keyboardShortcut(.upArrow, modifiers: [])
        }
        .opacity(0)
    }

    private func moveSelection(_ delta: Int) {
        guard !allResults.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), allResults.count - 1)
    }

    private func openSelected() {
        guard let result = selectedResult else { return }
        open(result)
    }

    private func open(_ result: GlobalSpotlightResult) {
        switch result {
        case .book(let book):
            selectedModule = .home
            selectedBook = book
        case .excerpt(let excerpt):
            selectedBook = nil
            selectedModule = .excerpts
            highlightedExcerptID = excerpt.id
        }
        close()
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.14)) {
            isClosing = true
            hasEntered = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isPresented = false
        }
    }
}

private enum GlobalSpotlightResult: Identifiable {
    case book(Book)
    case excerpt(Excerpt)

    var id: String {
        switch self {
        case .book(let book): return "book-\(book.id)"
        case .excerpt(let excerpt): return "excerpt-\(excerpt.id)"
        }
    }
}

private struct GlobalSpotlightResultCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let result: GlobalSpotlightResult
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppCard(cornerRadius: AppRadius.l) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                    .fill(isSelected ? AppColors.accentSoft(for: colorScheme).opacity(0.46) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                    .stroke(.primary.opacity(isSelected ? 0.10 : 0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        switch result {
        case .book(let book):
            HStack(spacing: AppSpacing.m) {
                BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                    .frame(width: 44, height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(book.author.isEmpty ? "未知作者" : book.author)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(book.status.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.readingAmber)
                }
                Spacer()
            }
        case .excerpt(let excerpt):
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                HStack(alignment: .top) {
                    Text(excerpt.book == nil ? excerpt.displayTitle : excerpt.book?.title ?? "摘录")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    CategoryCapsule(category: excerpt.category)
                }

                Text(excerpt.content)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(5)

                Text(excerpt.book == nil ? excerpt.displayAuthor : "来自《\(excerpt.book?.title ?? "未知书籍")》")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

}

private struct CategoryCapsule: View {
    let category: ExcerptCategory

    var body: some View {
        AppCapsuleLabel(
            text: category.displayName,
            tint: category.themeColor,
            fontWeight: .semibold,
            horizontalPadding: 9,
            verticalPadding: 5,
            fillOpacity: 0.12
        )
    }
}
#endif
