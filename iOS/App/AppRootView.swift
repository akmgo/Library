import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case library
    case logs
    case texts
}

struct AppRootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @Query(sort: \ReadingLog.date, order: .reverse) private var logs: [ReadingLog]
    @Query(sort: \BookText.createdAt, order: .reverse) private var texts: [BookText]

    @State private var selectedTab: AppTab = .library
    @State private var showAddBook = false
    @State private var showAddLog = false
    @State private var showAddText = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                LibraryView(books: books, onAddBook: { showAddBook = true })
            }
            .tabItem { Label("书架", systemImage: "books.vertical") }
            .tag(AppTab.library)

            NavigationStack {
                ReadingLogsView(logs: logs, onAddLog: { showAddLog = true })
            }
            .tabItem { Label("记录", systemImage: "calendar") }
            .tag(AppTab.logs)

            NavigationStack {
                BookTextsView(texts: texts, onAddText: { showAddText = true })
            }
            .tabItem { Label("摘记", systemImage: "quote.opening") }
            .tag(AppTab.texts)
        }
        .tint(AppTheme.accent)
        .background(AppTheme.background(colorScheme))
        .sheet(isPresented: $showAddBook) {
            AddBookSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddLog) {
            AddReadingLogSheet(books: books)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddText) {
            AddBookTextSheet(books: books)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}
