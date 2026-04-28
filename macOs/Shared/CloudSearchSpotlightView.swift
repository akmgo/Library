#if os(macOS)
import SwiftUI
import SwiftData

// MARK: - 🔍 空间计算级：全局云端探索引擎 (Apple Spotlight 级高定版)

struct CloudSearchSpotlightView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var results: [BookSearchResult] = []
    @State private var errorMessage: String? = nil
    
    @State private var importingBookID: UUID? = nil
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        ZStack {
            Color.white.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.blue.opacity(0.8))
                    
                    TextField("搜索书名、作者或 ISBN...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(.primary)
                        .focused($isSearchFocused)
                        .onSubmit { performSearch() }
                    
                    if isSearching {
                        ProgressView().controlSize(.small).padding(.trailing, 4)
                    } else if !searchText.isEmpty || !results.isEmpty {
                        Button(action: clearAndCollapse) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                
                let hasError = errorMessage != nil
                let hasResults = !results.isEmpty
                
                if hasError || hasResults {
                    Divider().opacity(0.3).padding(.horizontal, 16)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(32)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    } else if !results.isEmpty {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 6) {
                                ForEach(results) { result in
                                    // ✨ 彻底解耦：调用公共大一统组件
                                    UniversalSearchResultRow(
                                        result: result,
                                        mode: .spotlight,
                                        isImporting: importingBookID == result.id
                                    ) { fetchedCoverData in
                                        importBook(result, fetchedCoverData: fetchedCoverData)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                        }
                        .frame(maxHeight: 380)
                    }
                }
            }
            .frame(width: 720)
            .background(Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 24)))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 40, y: 20)
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: results.isEmpty)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: errorMessage == nil)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
        .zIndex(9999)
        .onExitCommand {
            if !searchText.isEmpty || !results.isEmpty || errorMessage != nil {
                clearAndCollapse()
            } else {
                dismiss()
            }
        }
        .onAppear {
            searchText = ""; results.removeAll(); errorMessage = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isSearchFocused = true }
        }
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isPresented = false }
    }
    
    private func clearAndCollapse() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            searchText = ""; results.removeAll(); errorMessage = nil
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            errorMessage = nil; results.removeAll()
        }
        Task { @MainActor in
            do {
                let fetchedResults = try await CloudSearchManager.shared.search(query: searchText)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    if fetchedResults.isEmpty { errorMessage = "未能在云端找到相关书籍，请尝试更换关键词。" }
                    else { results = fetchedResults }
                }
            } catch {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    errorMessage = "查询受阻：\(error.localizedDescription)"
                }
            }
            isSearching = false
        }
    }
    
    private func importBook(_ result: BookSearchResult, fetchedCoverData: Data?) {
        guard importingBookID == nil else { return }
        importingBookID = result.id
        Task { @MainActor in
            var finalCoverData = fetchedCoverData
            if finalCoverData == nil { finalCoverData = await CloudSearchManager.shared.fetchCoverData(from: result.coverURL) }
            
            let newBook = Book(title: result.title, author: result.author)
            newBook.coverData = finalCoverData
            newBook.status = .wantToRead
            
            modelContext.insert(newBook)
            try? modelContext.save()
            NotificationCenter.default.post(name: .libraryDidUpdate, object: nil)
            importingBookID = nil; dismiss()
        }
    }
}
#endif
