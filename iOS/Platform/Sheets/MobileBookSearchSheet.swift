#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 在线搜索添加书籍 Sheet

struct MobileBookSearchSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var query = ""
    @State private var results: [BookSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var importingID: UUID?
    @State private var didImportIDs: Set<UUID> = []
    @State private var searchTask: Task<Void, Never>?
    @State private var coverCache: [UUID: Data] = [:]

    // 进度设置子 sheet
    @State private var selectedResult: BookSearchResult?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                HStack(spacing: AppSpacing.s) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.readingAmber)
                    TextField("搜索书名、作者或 ISBN...", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                    if !query.isEmpty {
                        Button(action: { query = ""; results = []; errorMessage = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .appInnerBlockStyle(cornerRadius: AppRadius.m)
                .padding(.horizontal, AppSpacing.m)
                .padding(.vertical, AppSpacing.s)

                Divider()

                // 内容区
                if isSearching {
                    Spacer()
                    ProgressView("正在搜索...")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: AppSpacing.s) {
                        Image(systemName: "magnifyingglass").font(.system(size: 36)).foregroundColor(.secondary.opacity(0.5))
                        Text(error).font(.system(size: 14)).foregroundColor(.secondary)
                    }
                    Spacer()
                } else if results.isEmpty && !query.isEmpty {
                    Spacer()
                    Text("输入书名或作者开始搜索").font(.system(size: 14)).foregroundColor(.secondary)
                    Spacer()
                } else {
                    ScrollView(.vertical, showsIndicators: results.count > 5) {
                        LazyVStack(spacing: AppSpacing.s) {
                            ForEach(results) { result in
                                Button(action: { selectResult(result) }) {
                                    AppCard {
                                        searchResultRow(result)
                                    }
                                    .opacity(didImportIDs.contains(result.id) ? 0.55 : 1)
                                }
                                .buttonStyle(.plain)
                                .disabled(didImportIDs.contains(result.id) || importingID != nil)
                            }
                        }
                        .padding(AppSpacing.s)
                    }
                }
            }
            .background(AppColors.primaryBackground(for: colorScheme))
            .navigationTitle("添加书籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { isPresented = false }
                }
            }
            .sheet(item: $selectedResult) { result in
                ImportProgressSheet(
                    bookTitle: result.title,
                    onImport: { draft in importResult(result, draft: draft) }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: query) { _, newValue in
                triggerSearch(query: newValue)
            }
            .onDisappear { searchTask?.cancel() }
        }
    }

    // MARK: - 搜索结果行

    private func searchResultRow(_ result: BookSearchResult) -> some View {
        HStack(spacing: AppSpacing.s) {
            coverView(for: result)
                .frame(width: 48, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs, style: .continuous))

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(result.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Text(result.author)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if let desc = result.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                        .lineLimit(1)
                }
            }

            Spacer()

            trailingState(for: result)
        }
        .task(id: result.id) {
            guard coverCache[result.id] == nil,
                  let url = result.coverURL, !url.isEmpty
            else { return }
            if let data = await BookMetadataSearchManager.shared.fetchCoverData(from: url) {
                coverCache[result.id] = data
            }
        }
    }

    @ViewBuilder
    private func coverView(for result: BookSearchResult) -> some View {
        if let coverData = coverCache[result.id], let uiImage = UIImage(data: coverData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            Color.secondary.opacity(0.1)
                .overlay(Image(systemName: "book.closed").foregroundColor(.secondary.opacity(0.3)))
        }
    }

    @ViewBuilder
    private func trailingState(for result: BookSearchResult) -> some View {
        if didImportIDs.contains(result.id) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.success)
                .font(.system(size: 20))
        } else if importingID == result.id {
            ProgressView()
        } else {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColors.readingAmber)
                .frame(width: 30, height: 30)
                .background(AppColors.readingAmber.opacity(0.11), in: Circle())
        }
    }

    // MARK: - Actions

    private func selectResult(_ result: BookSearchResult) {
        selectedResult = result
    }

    private func triggerSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchTask?.cancel()
            results = []
            errorMessage = nil
            isSearching = false
            return
        }
        searchTask?.cancel()
        isSearching = true
        results = []
        errorMessage = nil
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(query: trimmed)
        }
    }

    private func performSearch(query: String) async {
        do {
            let fetched = try await BookMetadataSearchManager.shared.search(query: query)
            guard !Task.isCancelled else { return }
            results = Array(fetched.prefix(10))
            isSearching = false
            if results.isEmpty {
                errorMessage = "没有找到与「\(query)」相关的书籍"
            }
        } catch {
            guard !Task.isCancelled else { return }
            isSearching = false
            errorMessage = error.localizedDescription
        }
    }

    private func importResult(_ result: BookSearchResult, draft: ReadingProgressDraft) {
        Task {
            importingID = result.id
            var normalized = draft
            normalized.normalize()

            let cleanedTitle = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedAuthor = result.author.trimmingCharacters(in: .whitespacesAndNewlines)

            let coverData = await BookMetadataSearchManager.shared.fetchCoverData(from: result.coverURL)

            let book = Book(
                title: cleanedTitle,
                author: cleanedAuthor,
                coverData: coverData,
                totalAmount: normalized.totalAmount
            )

            try? ReadingDataService.shared.insertBook(book, context: modelContext)

            importingID = nil
            didImportIDs.insert(result.id)
            selectedResult = nil

            // 导入成功后短暂延迟再关闭
            try? await Task.sleep(nanoseconds: 500_000_000)
            if didImportIDs.count >= results.count || results.allSatisfy({ didImportIDs.contains($0.id) }) {
                isPresented = false
            }
        }
    }
}
// MARK: - 导入进度设置子视图

private struct ImportProgressSheet: View {
    let bookTitle: String
    let onImport: (ReadingProgressDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var totalPages: Double = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(bookTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .padding(.top, AppSpacing.xl)
                    .padding(.horizontal, AppSpacing.xl)

                HStack(spacing: AppSpacing.s) {
                    Text("总页数")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("0", value: $totalPages, format: .number.precision(.fractionLength(0)))
                        .textFieldStyle(.plain)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Text("页")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, AppSpacing.m)
                .frame(height: 52)
                .frame(maxWidth: .infinity)
                .appInnerBlockStyle(cornerRadius: AppRadius.m)
                .padding(AppSpacing.xl)

                HStack {
                    Button("取消") { dismiss() }
                        .buttonStyle(.plain)
                        .padding(.horizontal, AppSpacing.m).padding(.vertical, AppSpacing.xs)
                        .appCapsuleStyle(tint: .secondary, fillOpacity: 0.10, strokeOpacity: 0.08)

                    Spacer()

                    Button("确认导入") {
                        onImport(ReadingProgressDraft(totalAmount: totalPages))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppColors.readingAmber)
                    .padding(.horizontal, AppSpacing.l).padding(.vertical, AppSpacing.xs)
                    .appCapsuleStyle(tint: AppColors.readingAmber)
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppColors.primaryBackground(for: colorScheme))
            .navigationTitle("设置进度")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}


#if DEBUG
private struct PreviewMobileBookSearch: View {
    @State private var isPresented = true
    var body: some View {
        PreviewWithData {
            Color.clear
                .sheet(isPresented: $isPresented) {
                    MobileBookSearchSheet(isPresented: $isPresented)
                }
        }
    }
}

#Preview("在线搜书弹窗") {
    PreviewMobileBookSearch()
}
#endif


#endif
