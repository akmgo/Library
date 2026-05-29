#if os(macOS)
import SwiftUI
import SwiftData

// MARK: - ✨ 双列懒加载碎片渲染引擎
struct BookExcerpts: View {
    let book: Book
    let isDeleteMode: Bool
    
    // ✨ 修改为传入 Excerpt
    let onDelete: (Excerpt) -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var itemToEdit: Excerpt? = nil
    
    @State private var currentFilter: BookExcerptFilter = .all

    @State private var cachedSnapshot: ReadingStatsCalculator.BookExcerptListSnapshot = .init(excerpts: [], filter: .all)
    @State private var cachedRecordsByID: [String: Excerpt] = [:]

    private var excerptsFingerprint: String {
        "\(book.excerpts?.count ?? 0)-\(currentFilter)"
    }

    var body: some View {
        VStack(spacing: 24) {
            if !cachedSnapshot.isEmpty {
                AppSlidingSegmentedControl(
                    selection: $currentFilter,
                    options: BookExcerptFilter.allCases.map {
                        AppSlidingSegmentedOption(value: $0, title: "\($0.displayName) (\(cachedSnapshot.count(for: $0)))")
                    },
                    tint: AppColors.selection,
                    height: 32,
                    cornerRadius: AppRadius.m,
                    showsIcons: false
                )
                .frame(maxWidth: 280)
                .frame(maxWidth: .infinity)
            }
            
            if cachedSnapshot.filtered.isEmpty {
                EmptyView()
            } else {
                BookExcerptGrid(
                    items: cachedSnapshot.filtered,
                    columns: excerptColumns,
                    isDeleteMode: isDeleteMode,
                    onDelete: { item in
                        if let record = cachedRecordsByID[item.id] {
                            onDelete(record)
                        }
                    },
                    onEdit: { item in
                        itemToEdit = cachedRecordsByID[item.id]
                    }
                )
                .equatable()
            }
        }
        .sheet(item: $itemToEdit) { item in
            ContentEditorSheet(
                isPresented: Binding(
                    get: { itemToEdit != nil },
                    set: { isPresented in if !isPresented { itemToEdit = nil } }
                ),
                book: book,
                mode: item.isNote ? .note : .excerpt,
                itemToEdit: item
            )
        }
        .onAppear {
            refreshCachedData()
        }
        .onChange(of: excerptsFingerprint) { _, _ in
            refreshCachedData()
        }
    }

    private var excerptColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 24, alignment: .top),
            GridItem(.flexible(), spacing: 24, alignment: .top)
        ]
    }

    private func refreshCachedData() {
        let excerpts = book.excerpts ?? []
        cachedSnapshot = ReadingStatsCalculator.BookExcerptListSnapshot(excerpts: excerpts, filter: currentFilter)
        cachedRecordsByID = Dictionary(uniqueKeysWithValues: excerpts.map { ($0.id, $0) })
    }
}

private struct BookExcerptGrid: View, Equatable {
    let items: [ReadingStatsCalculator.BookExcerptItemSnapshot]
    let columns: [GridItem]
    let isDeleteMode: Bool
    let onDelete: (ReadingStatsCalculator.BookExcerptItemSnapshot) -> Void
    let onEdit: (ReadingStatsCalculator.BookExcerptItemSnapshot) -> Void

    static func == (lhs: BookExcerptGrid, rhs: BookExcerptGrid) -> Bool {
        lhs.items == rhs.items && lhs.isDeleteMode == rhs.isDeleteMode
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
            ForEach(items) { item in
                AnnotationCardWrapper(
                    item: item,
                    isDeleteMode: isDeleteMode,
                    onDelete: { onDelete(item) },
                    onEdit: { onEdit(item) }
                )
            }
        }
    }
}

// MARK: - 内部视图组件
struct AnnotationCardWrapper: View {
    let item: ReadingStatsCalculator.BookExcerptItemSnapshot
    let isDeleteMode: Bool
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if item.type == .bookExcerpt {
                    ExcerptCardView(excerpt: item, onEdit: onEdit)
                } else {
                    NoteCardView(note: item, onEdit: onEdit)
                }
            }
            if isDeleteMode {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .offset(x: 10, y: -10)
                .transition(.scale.combined(with: .opacity))
                .zIndex(1)
            }
        }
    }
}

struct ExcerptCardView: View {
    let excerpt: ReadingStatsCalculator.BookExcerptItemSnapshot
    let onEdit: () -> Void

    var body: some View {
        AppCard {
            BookExcerptCardContent(item: excerpt, contentFontSize: 16)
        }
        .onTapGesture(count: 2, perform: onEdit)
    }
}

struct NoteCardView: View {
    let note: ReadingStatsCalculator.BookExcerptItemSnapshot
    let onEdit: () -> Void

    var body: some View {
        AppCard {
            BookExcerptCardContent(item: note, contentFontSize: 15)
        }
        .onTapGesture(count: 2, perform: onEdit)
    }
}

struct BookExcerptsPreviewWrapper: View {
    @Query var books: [Book]
    var body: some View {
        if let book = books.first {
            ScrollView {
                BookExcerpts(
                    book: book,
                    isDeleteMode: false,
                    onDelete: { _ in }
                )
                .padding()
            }
            .frame(width: 900, height: 600)
        }
    }
}

#endif
