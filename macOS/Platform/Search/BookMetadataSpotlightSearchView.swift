#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

struct BookMetadataSpotlightSearchView: View {
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    @Binding var isPresented: Bool

    @State private var query = ""
    @State private var results: [BookSearchResult] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var duplicateTitle: String?
    @State private var importingID: UUID?
    @State private var importedID: UUID?
    @State private var didImport = false
    @State private var hasEntered = false
    @State private var isClosing = false
    @State private var isContentExpanded = false
    @State private var shouldRenderContent = false
    @State private var visibleResultIDs: Set<UUID> = []
    @State private var selectedResultIndex = 0
    @State private var progressOpenSignal = 0
    @FocusState private var isSearchFocused: Bool

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var panelWidth: CGFloat {
        isContentExpanded ? 700 : 640
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(colorScheme == .dark ? 0.28 : 0.14)
                .ignoresSafeArea()
                .onTapGesture { closeSpotlight() }
                .transition(.opacity)
                .opacity(hasEntered ? 1 : 0)

            VStack(spacing: 0) {
                searchField

                if shouldRenderContent {
                    Divider()
                        .opacity(isContentExpanded ? 0.28 : 0)
                        .padding(.horizontal, AppSpacing.m)

                    contentBody
                        .frame(maxHeight: isContentExpanded ? 560 : 0, alignment: .top)
                        .clipped()
                        .opacity(isContentExpanded ? 1 : 0.94)
                }
            }
            .frame(width: panelWidth)
            .background(Color(nsColor: .windowBackgroundColor), in: .rect(cornerRadius: AppRadius.panel))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.30 : 0.16), radius: 38, y: 20)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous)
                    .stroke(.primary.opacity(colorScheme == .dark ? 0.10 : 0.08), lineWidth: 1)
            )
            .padding(.top, 116)
            .scaleEffect(isClosing ? 0.965 : (hasEntered ? (didImport ? 0.985 : 1) : 0.955), anchor: .top)
            .opacity(hasEntered && !isClosing ? 1 : 0)
            .offset(y: hasEntered && !isClosing ? 0 : -18)
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.90), value: isContentExpanded)
        .animation(.spring(response: 0.46, dampingFraction: 0.88), value: panelWidth)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: hasEntered)
        .animation(.easeOut(duration: 0.16), value: isClosing)
        .onAppear {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                hasEntered = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                isSearchFocused = true
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
        .background(
            Button("") { handleEscape() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
        )
    }

    private var searchField: some View {
        HStack(spacing: AppSpacing.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(AppColors.readingAmber)
                .frame(width: 36)

            TextField("搜索书名、作者或 ISBN...", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 28, weight: .medium))
                .focused($isSearchFocused)
                .onChange(of: query) { _, newValue in
                    duplicateTitle = nil
                    if errorMessage != nil && !isSearching {
                        errorMessage = nil
                    }
                    triggerSearch(query: newValue)
                }

            trailingControl
        }
        .padding(.horizontal, AppSpacing.l)
        .frame(height: 82)
        .contentShape(Rectangle())
        .onTapGesture { isSearchFocused = true }
    }

    @ViewBuilder
    private var trailingControl: some View {
        EmptyView()
    }

    @ViewBuilder
    private var contentBody: some View {
        if didImport {
            successState
        } else if let duplicateTitle {
            messageState(icon: "exclamationmark.circle.fill", title: "书库中已有这本书", detail: duplicateTitle, tint: AppColors.warning)
        } else if let errorMessage {
            messageState(icon: "wifi.exclamationmark", title: "暂时没有拿到结果", detail: errorMessage, tint: AppColors.warning)
        } else {
            resultList
        }
    }

    private var resultList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.vertical, showsIndicators: results.count > 7) {
                LazyVStack(spacing: 4) {
                    ForEach(Array(results.prefix(10).enumerated()), id: \.element.id) { index, result in
                        BookMetadataSpotlightResultRow(
                            result: result,
                            isSelected: index == selectedResultIndex,
                            isDimmed: importingID != nil && importingID != result.id,
                            isImporting: importingID == result.id,
                            isImported: importedID == result.id,
                            openProgressSignal: progressOpenSignal
                        ) { coverData, progressDraft in
                            importResult(result, coverData: coverData, progressDraft: progressDraft)
                        }
                        .onTapGesture {
                            selectedResultIndex = index
                        }
                        .opacity(visibleResultIDs.contains(result.id) ? 1 : 0)
                        .animation(.easeOut(duration: 0.16).delay(Double(index) * 0.018), value: visibleResultIDs)
                    }
                }
                .padding(.horizontal, AppSpacing.s)
                .padding(.vertical, AppSpacing.s)
            }
            .frame(maxHeight: 540)
        }
    }

    private var successState: some View {
        VStack(spacing: AppSpacing.s) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppColors.success)
                .symbolEffect(.bounce, value: didImport)

            Text("已加入书库")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
    }

    private func messageState(icon: String, title: String, detail: String, tint: Color) -> some View {
        HStack(spacing: AppSpacing.s) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(AppSpacing.l)
    }

    private func triggerSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchTask?.cancel()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                results.removeAll()
                errorMessage = nil
                duplicateTitle = nil
                didImport = false
                importedID = nil
                isSearching = false
                isContentExpanded = false
                shouldRenderContent = false
            }
            return
        }
        searchTask?.cancel()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            visibleResultIDs.removeAll()
            results.removeAll()
            errorMessage = nil
            duplicateTitle = nil
            didImport = false
            importedID = nil
            isSearching = true
            isContentExpanded = false
            shouldRenderContent = false
            selectedResultIndex = 0
        }
        let captured = trimmed
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, captured == trimmedQuery else { return }
            await search(captured)
        }
    }

    private func performSearch() {
        searchTask?.cancel()
        let cleaned = trimmedQuery
        guard !cleaned.isEmpty else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            visibleResultIDs.removeAll()
            results.removeAll()
            errorMessage = nil
            duplicateTitle = nil
            didImport = false
            importedID = nil
            isSearching = true
            isContentExpanded = false
            shouldRenderContent = false
            selectedResultIndex = 0
        }
        Task { @MainActor in
            await search(cleaned)
        }
    }

    @MainActor
    private func search(_ cleaned: String) async {
        do {
            let fetched = try await BookMetadataSearchManager.shared.search(query: cleaned)
            guard cleaned == trimmedQuery else { return }
            let limitedResults = Array(fetched.prefix(10))
            results = limitedResults
            selectedResultIndex = 0
            visibleResultIDs.removeAll()
            shouldRenderContent = true
            withAnimation(.spring(response: 0.50, dampingFraction: 0.90)) {
                errorMessage = fetched.isEmpty ? "没有找到与 “\(cleaned)” 相关的书籍。" : nil
                isSearching = false
                isContentExpanded = true
            }
            revealResultRows(limitedResults)
        } catch {
            guard cleaned == trimmedQuery else { return }
            results.removeAll()
            selectedResultIndex = 0
            visibleResultIDs.removeAll()
            shouldRenderContent = true
            withAnimation(.spring(response: 0.50, dampingFraction: 0.90)) {
                errorMessage = error.localizedDescription
                isSearching = false
                isContentExpanded = true
            }
        }
    }

    private func importResult(_ result: BookSearchResult, coverData: Data?, progressDraft: ReadingProgressDraft) {
        guard importingID == nil else { return }

        let cleanedTitle = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedAuthor = result.author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return }
        guard progressDraft.isValidForBookImport else { return }

        if books.contains(where: { $0.title == cleanedTitle }) {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.9)) {
                duplicateTitle = cleanedTitle
                isContentExpanded = true
            }
            return
        }

        importingID = result.id

        Task { @MainActor in
            let finalCoverData: Data?
            if let coverData {
                finalCoverData = coverData
            } else {
                finalCoverData = await BookMetadataSearchManager.shared.fetchCoverData(from: result.coverURL)
            }
            let book = Book(
                title: cleanedTitle,
                author: cleanedAuthor,
                coverData: finalCoverData,
                progressUnit: progressDraft.unit,
                totalAmount: progressDraft.totalAmount,
                currentAmount: 0
            )

            do {
                try ReadingDataService.shared.insertBook(book, context: modelContext)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    importedID = result.id
                    didImport = true
                }
                try? await Task.sleep(nanoseconds: 620_000_000)
                closeSpotlight()
            } catch {
                withAnimation(.appSnappy) {
                    errorMessage = error.localizedDescription
                    importingID = nil
                    importedID = nil
                }
            }
        }
    }

    private func handleEscape() {
        if isContentExpanded {
            collapseContent()
        } else {
            closeSpotlight()
        }
    }

    private func handleReturn() {
        guard isContentExpanded, !results.isEmpty else { return }
        selectedResultIndex = min(max(selectedResultIndex, 0), results.prefix(10).count - 1)
        progressOpenSignal += 1
    }

    private var shortcuts: some View {
        Group {
            Button("") { handleEscape() }
                .keyboardShortcut(.cancelAction)
            Button("") { handleReturn() }
                .keyboardShortcut(.return)
            Button("") { moveSelection(1) }
                .keyboardShortcut(.downArrow, modifiers: [])
            Button("") { moveSelection(-1) }
                .keyboardShortcut(.upArrow, modifiers: [])
        }
        .opacity(0)
    }

    private func moveSelection(_ delta: Int) {
        guard isContentExpanded, !results.isEmpty else { return }
        selectedResultIndex = min(max(selectedResultIndex + delta, 0), results.prefix(10).count - 1)
    }

    private func collapseContent() {
        searchTask?.cancel()
        query = ""
        hideResultRows()
        withAnimation(.spring(response: 0.46, dampingFraction: 0.90)) {
            isContentExpanded = false
            isSearching = false
            duplicateTitle = nil
            didImport = false
            importedID = nil
            importingID = nil
            selectedResultIndex = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            guard !isContentExpanded else { return }
            shouldRenderContent = false
            results.removeAll()
            errorMessage = nil
            visibleResultIDs.removeAll()
        }
    }

    private func revealResultRows(_ rows: [BookSearchResult]) {
        for (index, result) in rows.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06 + Double(index) * 0.028) {
                guard isContentExpanded, results.contains(where: { $0.id == result.id }) else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    _ = visibleResultIDs.insert(result.id)
                }
            }
        }
    }

    private func hideResultRows() {
        for (offset, result) in results.prefix(10).reversed().enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(offset) * 0.014) {
                withAnimation(.easeOut(duration: 0.14)) {
                    _ = visibleResultIDs.remove(result.id)
                }
            }
        }
    }

    private func closeSpotlight() {
        searchTask?.cancel()
        withAnimation(.easeOut(duration: 0.14)) {
            isClosing = true
            hasEntered = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            isPresented = false
        }
    }
}

private struct BookMetadataSpotlightResultRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let result: BookSearchResult
    let isSelected: Bool
    let isDimmed: Bool
    let isImporting: Bool
    let isImported: Bool
    let openProgressSignal: Int
    let onImport: (Data?, ReadingProgressDraft) -> Void

    @State private var coverData: Data?
    @State private var coverImage: NSImage?
    @State private var isLoadingCover = false
    @State private var isProgressPopoverPresented = false
    @State private var progressDraft = ReadingProgressDraft.bookImportDefault

    var body: some View {
        AppCard(cornerRadius: AppRadius.l) {
            HStack(spacing: AppSpacing.m) {
                coverView

                VStack(alignment: .leading, spacing: 7) {
                    Text(result.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(result.author.isEmpty ? "未知作者" : result.author)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(publisherText)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: AppSpacing.s)

                trailingState
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous)
                .fill(isSelected ? AppColors.accentSoft(for: colorScheme).opacity(0.42) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.l, style: .continuous))
        .opacity(isDimmed ? 0.38 : 1)
        .disabled(isDimmed || isImporting || isImported)
        .task(id: result.coverURL) {
            guard let url = result.coverURL, !url.isEmpty else { return }
            isLoadingCover = true
            let fetchedData = await BookMetadataSearchManager.shared.fetchCoverData(from: url)
            coverData = fetchedData
            if let fetchedData {
                coverImage = NSImage(data: fetchedData)
            }
            isLoadingCover = false
        }
        .onChange(of: openProgressSignal) { _, _ in
            guard isSelected, !isDimmed, !isImporting, !isImported else { return }
            progressDraft = .bookImportDefault
            isProgressPopoverPresented = true
        }
    }

    private var publisherText: String {
        guard let description = result.description, !description.isEmpty else {
            return "出版社未知"
        }

        let parts = description
            .components(separatedBy: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let author = result.author.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = parts.filter { part in
            guard part != author else { return false }
            let lower = part.lowercased()
            return !lower.contains("作者") && !lower.contains("译者") && !part.contains("年") && !part.contains("月")
        }

        return candidates.first ?? parts.dropFirst().first ?? "出版社未知"
    }

    @ViewBuilder
    private var trailingState: some View {
        if isImported {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColors.success)
        } else if isImporting {
            ProgressView()
                .controlSize(.small)
        } else {
            Button {
                progressDraft = .bookImportDefault
                isProgressPopoverPresented = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColors.readingAmber)
                    .frame(width: 36, height: 36)
                    .background(AppColors.readingAmber.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(isDimmed)
            .popover(isPresented: $isProgressPopoverPresented, arrowEdge: .trailing) {
                importProgressPopover
            }
        }
    }

    private var importProgressPopover: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            VStack(alignment: .leading, spacing: 4) {
                Text("设置进度单位")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                Text(result.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ReadingProgressInputView(
                draft: $progressDraft,
                mode: .bookImport
            )

            Button {
                var normalized = progressDraft
                normalized.normalize()
                guard normalized.isValidForBookImport else { return }
                isProgressPopoverPresented = false
                onImport(coverData, normalized)
            } label: {
                Text("确认导入")
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(progressDraft.isValidForBookImport ? Color.white : Color.secondary)
            .appCapsuleStyle(
                tint: progressDraft.isValidForBookImport ? AppColors.readingAmber : Color.secondary,
                fillOpacity: progressDraft.isValidForBookImport ? 1 : 0.12,
                strokeOpacity: progressDraft.isValidForBookImport ? 0 : 0.08
            )
            .disabled(!progressDraft.isValidForBookImport)
            .keyboardShortcut(.defaultAction)

            Button("取消") {
                isProgressPopoverPresented = false
            }
            .keyboardShortcut(.cancelAction)
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        .padding(18)
        .frame(width: 292)
    }

    private var coverView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous)
                .fill(.regularMaterial)

            if let image = coverImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoadingCover {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: "book.closed")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.55))
            }
        }
        .frame(width: 44, height: 66)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }

}

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
            selectedModule = .gallery
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
