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
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: AppRadius.panel))
            .background(.regularMaterial, in: .rect(cornerRadius: AppRadius.panel))
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
                .onSubmit { performSearch() }
                .onChange(of: query) { _, _ in
                    duplicateTitle = nil
                    if errorMessage != nil && !isSearching {
                        errorMessage = nil
                    }
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
                VStack(spacing: 4) {
                    ForEach(Array(results.prefix(10).enumerated()), id: \.element.id) { index, result in
                        BookMetadataSpotlightResultRow(
                            result: result,
                            isDimmed: importingID != nil && importingID != result.id,
                            isImporting: importingID == result.id,
                            isImported: importedID == result.id
                        ) { coverData in
                            importResult(result, coverData: coverData)
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
            visibleResultIDs.removeAll()
            shouldRenderContent = true
            withAnimation(.spring(response: 0.50, dampingFraction: 0.90)) {
                errorMessage = error.localizedDescription
                isSearching = false
                isContentExpanded = true
            }
        }
    }

    private func importResult(_ result: BookSearchResult, coverData: Data?) {
        guard importingID == nil else { return }

        let cleanedTitle = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedAuthor = result.author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return }

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
            let book = Book(title: cleanedTitle, author: cleanedAuthor, coverData: finalCoverData)

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
    let isDimmed: Bool
    let isImporting: Bool
    let isImported: Bool
    let onSelect: (Data?) -> Void

    @State private var coverData: Data?
    @State private var coverImage: NSImage?
    @State private var isLoadingCover = false
    @State private var isHovered = false

    var body: some View {
        Button {
            onSelect(coverData)
        } label: {
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
            .padding(.horizontal, AppSpacing.m)
            .padding(.vertical, 10)
            .frame(minHeight: 82, alignment: .center)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous))
            .background(rowBackground)
            .opacity(isDimmed ? 0.38 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDimmed || isImporting || isImported)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovered = hovering }
        }
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
        }
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

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
            .fill(isHovered ? AppColors.accentSoft(for: colorScheme).opacity(0.36) : Color.clear)
    }
}
#endif
