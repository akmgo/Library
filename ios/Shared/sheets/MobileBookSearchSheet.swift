#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 在线搜索添加书籍 Sheet

struct MobileBookSearchSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext

    @State private var query = ""
    @State private var results: [BookSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var importingID: UUID?
    @State private var didImportIDs: Set<UUID> = []
    @State private var searchTask: Task<Void, Never>?

    // 进度设置子 sheet
    @State private var selectedResult: BookSearchResult?
    @State private var showProgressSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                HStack(spacing: AppSpacing.s) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索书名、作者或 ISBN...", text: $query)
                        .textFieldStyle(.plain)
                        .onSubmit { performSearch() }
                    if !query.isEmpty {
                        Button(action: { query = ""; results = []; errorMessage = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AppSpacing.s)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous))
                .padding(AppSpacing.m)

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
                    Text("输入书名或作者后按回车搜索").font(.system(size: 14)).foregroundColor(.secondary)
                    Spacer()
                } else {
                    List {
                        ForEach(results) { result in
                            Button(action: { selectResult(result) }) {
                                searchResultRow(result)
                            }
                            .buttonStyle(.plain)
                            .disabled(didImportIDs.contains(result.id))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("添加书籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { isPresented = false }
                }
            }
            .sheet(isPresented: $showProgressSheet) {
                if let selected = selectedResult {
                    importProgressSheet(result: selected)
                }
            }
            .onDisappear { searchTask?.cancel() }
        }
    }

    // MARK: - 搜索结果行

    private func searchResultRow(_ result: BookSearchResult) -> some View {
        HStack(spacing: AppSpacing.s) {
            AsyncImage(url: URL(string: result.coverURL ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Color.secondary.opacity(0.1)
                        .overlay(Image(systemName: "book.closed").foregroundColor(.secondary.opacity(0.3)))
                }
            }
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

            if didImportIDs.contains(result.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
                    .font(.system(size: 20))
            } else if importingID == result.id {
                ProgressView()
            } else {
                Image(systemName: "plus.circle")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 20))
            }
        }
        .padding(.vertical, AppSpacing.xxs)
    }

    // MARK: - 导入进度设置 Sheet

    private func importProgressSheet(result: BookSearchResult) -> some View {
        ImportProgressSheet(
            bookTitle: result.title,
            isPresented: $showProgressSheet,
            onImport: { draft in importResult(result, draft: draft) }
        )
    }

    // MARK: - Actions

    private func selectResult(_ result: BookSearchResult) {
        selectedResult = result
        showProgressSheet = true
    }

    private func performSearch() {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        searchTask?.cancel()
        isSearching = true
        results = []
        errorMessage = nil
        searchTask = Task {
            do {
                let fetched = try await BookMetadataSearchManager.shared.search(query: cleaned)
                guard !Task.isCancelled else { return }
                results = Array(fetched.prefix(10))
                isSearching = false
                if results.isEmpty {
                    errorMessage = "没有找到与「\(cleaned)」相关的书籍"
                }
            } catch {
                guard !Task.isCancelled else { return }
                isSearching = false
                errorMessage = error.localizedDescription
            }
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
                progressUnit: normalized.unit,
                totalAmount: normalized.totalAmount,
                currentAmount: 0
            )

            try? ReadingDataService.shared.insertBook(book, context: modelContext)

            importingID = nil
            didImportIDs.insert(result.id)
            showProgressSheet = false

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
    @Binding var isPresented: Bool
    let onImport: (ReadingProgressDraft) -> Void

    @State private var progressDraft = ReadingProgressDraft.bookImportDefault

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(bookTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .padding(.top, AppSpacing.xl)
                    .padding(.horizontal, AppSpacing.xl)

                ReadingProgressInputView(draft: $progressDraft, mode: .bookImport)
                    .padding(AppSpacing.xl)

                HStack {
                    Button("取消") { isPresented = false }
                        .buttonStyle(.plain)
                        .padding(.horizontal, AppSpacing.m).padding(.vertical, AppSpacing.xs)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())

                    Spacer()

                    Button("确认导入") {
                        onImport(progressDraft)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.l).padding(.vertical, AppSpacing.xs)
                    .background(AppColors.readingAmber)
                    .clipShape(Capsule())
                    .disabled(!progressDraft.isValidForBookImport)
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xl)
            }
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
