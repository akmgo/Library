#if os(iOS) && DEBUG
import SwiftUI
import SwiftData

// MARK: - Preview ModelContainer

/// Shared ModelContainer for previews. Uses SharedDatabase which auto-detects Xcode preview mode.
@MainActor
var previewModelContainer: ModelContainer {
    SharedDatabase.shared.container
}

// MARK: - Sample Data Seeder

/// Seeds realistic sample data into a ModelContext for meaningful previews.
@MainActor
enum PreviewDataSeeder {
    static func seed(in context: ModelContext) {
        // Only seed once
        let existing = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        if !existing.isEmpty { return }

        let calendar = Calendar.current
        let today = Date()

        // ── 1. 在读 ──
        let book1 = Book(
            title: "三体",
            author: "刘慈欣",
            status: .reading,
            rating: 5,
            tags: ["科幻", "中国"],
            startDate: calendar.date(byAdding: .day, value: -21, to: today),
            lastReadAt: today,
            totalAmount: 320,
            currentAmount: 156,
            summary: "文化大革命如火如荼进行的同时，军方探寻外星文明的绝秘计划红岸工程取得了突破性进展。"
        )
        context.insert(book1)

        let book2 = Book(
            title: "活着",
            author: "余华",
            status: .reading,
            rating: 4,
            tags: ["文学", "中国"],
            startDate: calendar.date(byAdding: .day, value: -14, to: today),
            lastReadAt: calendar.date(byAdding: .hour, value: -3, to: today),
            totalAmount: 192,
            currentAmount: 80,
            summary: "地主少爷富贵嗜赌成性，终于赌光了家业一贫如洗。"
        )
        context.insert(book2)

        let book3 = Book(
            title: "1984",
            author: "George Orwell",
            status: .reading,
            rating: 4,
            tags: ["反乌托邦", "政治"],
            startDate: calendar.date(byAdding: .day, value: -7, to: today),
            lastReadAt: calendar.date(byAdding: .day, value: -1, to: today),
            totalAmount: 100,
            currentAmount: 62,
            summary: "战争即和平，自由即奴役，无知即力量。"
        )
        context.insert(book3)

        // ── 2. 想读 ──
        let book4 = Book(
            title: "苏菲的世界",
            author: "Jostein Gaarder",
            status: .planned,
            rating: 0,
            tags: ["哲学", "小说"],
            totalAmount: 544,
            currentAmount: 0
        )
        context.insert(book4)

        let book5 = Book(
            title: "人类简史",
            author: "Yuval Noah Harari",
            status: .planned,
            rating: 0,
            tags: ["历史", "社科"],
            totalAmount: 440,
            currentAmount: 0
        )
        context.insert(book5)

        // ── 3. 已读完 ──
        let book6 = Book(
            title: "局外人",
            author: "Albert Camus",
            status: .finished,
            rating: 5,
            tags: ["文学", "哲学"],
            startDate: calendar.date(byAdding: .day, value: -60, to: today),
            finishDate: calendar.date(byAdding: .day, value: -45, to: today),
            lastReadAt: calendar.date(byAdding: .day, value: -45, to: today),
            totalAmount: 128,
            currentAmount: 128,
            summary: "今天，妈妈死了。也许是昨天，我不知道。"
        )
        context.insert(book6)

        let book7 = Book(
            title: "Designing Data-Intensive Applications",
            author: "Martin Kleppmann",
            status: .finished,
            rating: 5,
            tags: ["技术", "分布式"],
            startDate: calendar.date(byAdding: .day, value: -90, to: today),
            finishDate: calendar.date(byAdding: .day, value: -30, to: today),
            lastReadAt: calendar.date(byAdding: .day, value: -30, to: today),
            totalAmount: 616,
            currentAmount: 616
        )
        context.insert(book7)

        // ── 4. Reading Sessions (过去 21 天) ──
        let dailyMinutes: [Double] = [45, 30, 60, 0, 25, 50, 40, 0, 35, 55, 20, 0, 45, 60, 30, 0, 40, 25, 50, 35, 45]
        for i in 0..<21 {
            guard let date = calendar.date(byAdding: .day, value: -(20 - i), to: today) else { continue }
            let minutes = dailyMinutes[i]
            if minutes > 0 {
                let startedAt = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: date)!
                let session = ReadingSession(
                    date: date,
                    inputMode: i % 3 == 0 ? .timer : .manual,
                    startedAt: startedAt,
                    duration: minutes * 60,
                    startAmount: Double(i * 5),
                    endAmount: Double(i * 5) + minutes * 0.5,
                    book: [book1, book2, book3][i % 3]
                )
                context.insert(session)
            }
        }

        // ── 5. Excerpts ──
        let excerpt1 = Excerpt(
            content: "给岁月以文明，而不是给文明以岁月。",
            category: .bookExcerpt,
            title: "三体",
            sourceAuthor: "刘慈欣",
            createdAt: calendar.date(byAdding: .day, value: -10, to: today)!,
            book: book1
        )
        context.insert(excerpt1)

        let excerpt2 = Excerpt(
            content: "人是为活着本身而活着的，而不是为了活着之外的任何事物所活着。",
            category: .bookExcerpt,
            title: "活着",
            sourceAuthor: "余华",
            createdAt: calendar.date(byAdding: .day, value: -7, to: today)!,
            book: book2
        )
        context.insert(excerpt2)

        let excerpt3 = Excerpt(
            content: "谁控制了过去，谁就控制了未来；谁控制了现在，谁就控制了过去。",
            category: .bookExcerpt,
            title: "1984",
            sourceAuthor: "George Orwell",
            createdAt: calendar.date(byAdding: .day, value: -3, to: today)!,
            book: book3
        )
        context.insert(excerpt3)

        let independentExcerpt = Excerpt(
            content: "春江潮水连海平，海上明月共潮生。滟滟随波千万里，何处春江无月明。",
            category: .poetry,
            title: "春江花月夜",
            sourceAuthor: "张若虚",
            source: "唐代诗人张若虚的孤篇横绝之作，被誉为'诗中的诗，顶峰上的顶峰'。",
            createdAt: calendar.date(byAdding: .day, value: -15, to: today)!,
            book: nil
        )
        context.insert(independentExcerpt)

        let noteExcerpt = Excerpt(
            content: "阅读时想到：文明的意义不在于存续多久，而在于存续时是否有光。",
            category: .note,
            title: "读三体有感",
            createdAt: calendar.date(byAdding: .day, value: -5, to: today)!,
            book: book1
        )
        context.insert(noteExcerpt)

        // ── 6. UserConfig ──
        let config = UserConfig()
        config.dailyMinutesGoal = 30
        config.yearlyBooksGoal = 20
        config.libraryBooksGoal = 100
        config.updatedAt = today
        context.insert(config)

        try? context.save()
    }
}

// MARK: - View Wrappers

/// Wraps content in a ModelContainer with seeded sample data.
struct PreviewWithData<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .modelContainer(previewModelContainer)
            .onAppear {
                let context = previewModelContainer.mainContext
                PreviewDataSeeder.seed(in: context)
            }
    }
}

/// Creates a single Book in a ModelContext and passes it to content.
struct PreviewWithBook<Content: View>: View {
    @Environment(\.modelContext) private var modelContext
    @State private var book: Book?
    let title: String
    let author: String
    let status: BookStatus
    let totalAmount: Double
    let currentAmount: Double
    let content: (Book) -> Content

    init(
        title: String = "三体",
        author: String = "刘慈欣",
        status: BookStatus = .reading,
        totalAmount: Double = 320,
        currentAmount: Double = 156,
        @ViewBuilder content: @escaping (Book) -> Content
    ) {
        self.title = title
        self.author = author
        self.status = status
        self.totalAmount = totalAmount
        self.currentAmount = currentAmount
        self.content = content
    }

    var body: some View {
        Group {
            if let book {
                content(book)
            } else {
                ProgressView()
                    .onAppear {
                        let b = Book(
                            title: title,
                            author: author,
                            status: status,
                            totalAmount: totalAmount,
                            currentAmount: currentAmount
                        )
                        modelContext.insert(b)
                        book = b
                    }
            }
        }
    }
}

/// Creates multiple Books and passes them to content.
struct PreviewWithBooks<Content: View>: View {
    @Environment(\.modelContext) private var modelContext
    @State private var books: [Book] = []
    let specs: [(title: String, author: String, status: BookStatus, total: Double, current: Double)]
    let content: ([Book]) -> Content

    init(
        specs: [(title: String, author: String, status: BookStatus, total: Double, current: Double)],
        @ViewBuilder content: @escaping ([Book]) -> Content
    ) {
        self.specs = specs
        self.content = content
    }

    var body: some View {
        Group {
            if !books.isEmpty {
                content(books)
            } else {
                ProgressView()
                    .onAppear {
                        books = specs.map { spec in
                            let b = Book(
                                title: spec.title,
                                author: spec.author,
                                status: spec.status,
                                totalAmount: spec.total,
                                currentAmount: spec.current
                            )
                            modelContext.insert(b)
                            return b
                        }
                    }
            }
        }
    }
}

/// Sheet preview helper that presents a sheet over a clear background.
struct PreviewSheet<SheetContent: View>: View {
    @State private var isPresented = true
    let sheet: () -> SheetContent

    init(@ViewBuilder sheet: @escaping () -> SheetContent) {
        self.sheet = sheet
    }

    var body: some View {
        Color.clear
            .sheet(isPresented: $isPresented) {
                sheet()
            }
    }
}

// MARK: - Legacy Compatibility

/// Shared preview helper that creates sample SwiftData models.
/// Prefer using PreviewWithBook / PreviewWithBooks wrappers for proper context association.
enum PreviewBookFactory {
    @MainActor
    static func makeSampleBook(
        title: String = "三体",
        author: String = "刘慈欣",
        status: BookStatus = .reading,
        totalAmount: Double = 320,
        currentAmount: Double = 156
    ) -> Book {
        Book(
            title: title,
            author: author,
            status: status,
            totalAmount: totalAmount,
            currentAmount: currentAmount
        )
    }

    @MainActor
    static func makeSampleBooks() -> [Book] {
        [
            makeSampleBook(),
            makeSampleBook(title: "活着", author: "余华", currentAmount: 80),
            makeSampleBook(title: "1984", author: "George Orwell", currentAmount: 200),
            makeSampleBook(title: "苏菲的世界", author: "Jostein Gaarder", status: .planned, currentAmount: 0),
        ]
    }
}
#endif
