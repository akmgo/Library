import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case today
    case library
    case texts
    case logs
}

struct AppRootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @Query(sort: \ReadingLog.date, order: .reverse) private var logs: [ReadingLog]
    @Query(sort: \BookText.createdAt, order: .reverse) private var texts: [BookText]

    @State private var selectedTab: AppTab = .today
    @State private var showAddBook = false
    @State private var showAddLog = false
    @State private var showAddText = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView(
                    books: books,
                    logs: logs,
                    texts: texts,
                    onAddBook: { showAddBook = true },
                    onAddLog: { showAddLog = true },
                    onAddText: { showAddText = true }
                )
            }
            .tabItem { Label("今日", systemImage: "rectangle.stack") }
            .tag(AppTab.today)

            NavigationStack {
                LibraryView(books: books, onAddBook: { showAddBook = true })
            }
            .tabItem { Label("书库", systemImage: "books.vertical") }
            .tag(AppTab.library)

            NavigationStack {
                BookTextsView(texts: texts, onAddText: { showAddText = true })
            }
            .tabItem { Label("摘录", systemImage: "quote.opening") }
            .tag(AppTab.texts)

            NavigationStack {
                ReadingLogsView(logs: logs, onAddLog: { showAddLog = true })
            }
            .tabItem { Label("记录", systemImage: "calendar") }
            .tag(AppTab.logs)
        }
        .tint(AppTheme.accent)
        .background(AppTheme.background(colorScheme))
        .sheet(isPresented: $showAddBook) {
            AddBookSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAddLog) {
            AddReadingLogSheet(books: books)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAddText) {
            AddBookTextSheet(books: books)
                .presentationDetents([.large])
        }
    }
}
