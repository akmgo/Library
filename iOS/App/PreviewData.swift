#if DEBUG
import SwiftData
import SwiftUI

struct PreviewLibraryData {
    let container: ModelContainer
    let books: [Book]
    let logs: [ReadingLog]
    let texts: [BookText]
}

enum PreviewData {
    static func make() -> PreviewLibraryData {
        let schema = Schema([
            Book.self,
            ReadingLog.self,
            BookText.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let data = makeDataset()
        let context = ModelContext(container)

        for book in data.books {
            context.insert(book)
        }
        for log in data.logs {
            context.insert(log)
        }
        for text in data.texts {
            context.insert(text)
        }
        try? context.save()

        return PreviewLibraryData(
            container: container,
            books: data.books,
            logs: data.logs,
            texts: data.texts
        )
    }

    static func emptyContainer() -> ModelContainer {
        let schema = Schema([
            Book.self,
            ReadingLog.self,
            BookText.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    private static func makeDataset() -> (books: [Book], logs: [ReadingLog], texts: [BookText]) {
        let calendar = Calendar.current
        let now = Date()

        let currentlyReading = Book(
            title: "夜航西飞",
            author: "柏瑞尔·马卡姆",
            publisher: "人民文学出版社",
            status: .reading,
            totalPages: 312,
            currentPage: 146,
            createdAt: calendar.date(byAdding: .day, value: -18, to: now) ?? now
        )
        currentlyReading.startDate = calendar.date(byAdding: .day, value: -12, to: now)

        let secondReading = Book(
            title: "沉思录",
            author: "马可·奥勒留",
            publisher: "中华书局",
            status: .reading,
            totalPages: 256,
            currentPage: 88,
            createdAt: calendar.date(byAdding: .day, value: -22, to: now) ?? now
        )
        secondReading.startDate = calendar.date(byAdding: .day, value: -8, to: now)

        let thirdReading = Book(
            title: "亲密关系",
            author: "罗兰·米勒",
            publisher: "人民邮电出版社",
            status: .reading,
            totalPages: 572,
            currentPage: 231,
            createdAt: calendar.date(byAdding: .day, value: -30, to: now) ?? now
        )
        thirdReading.startDate = calendar.date(byAdding: .day, value: -16, to: now)

        let finished = Book(
            title: "置身事内",
            author: "兰小欢",
            publisher: "上海人民出版社",
            status: .finished,
            totalPages: 340,
            currentPage: 340,
            rating: 6,
            createdAt: calendar.date(byAdding: .day, value: -44, to: now) ?? now
        )
        finished.startDate = calendar.date(byAdding: .day, value: -38, to: now)
        finished.finishDate = calendar.date(byAdding: .day, value: -4, to: now)

        let planned = Book(
            title: "悉达多",
            author: "赫尔曼·黑塞",
            publisher: "译林出版社",
            status: .planned,
            totalPages: 208,
            createdAt: calendar.date(byAdding: .day, value: -3, to: now) ?? now
        )

        let longBook = Book(
            title: "文学回忆录",
            author: "木心",
            publisher: "广西师范大学出版社",
            status: .planned,
            totalPages: 1100,
            currentPage: 260,
            createdAt: calendar.date(byAdding: .day, value: -60, to: now) ?? now
        )

        let log1 = ReadingLog(
            book: currentlyReading,
            date: calendar.date(byAdding: .hour, value: -2, to: now) ?? now,
            minutes: 42,
            pageAfterReading: 146
        )
        let log2 = ReadingLog(
            book: currentlyReading,
            date: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
            minutes: 35,
            pageAfterReading: 128
        )
        let log3 = ReadingLog(
            book: finished,
            date: calendar.date(byAdding: .day, value: -4, to: now) ?? now,
            minutes: 68,
            pageAfterReading: 340
        )
        let log4 = ReadingLog(
            book: secondReading,
            date: calendar.date(byAdding: .hour, value: -8, to: now) ?? now,
            minutes: 28,
            pageAfterReading: 88
        )
        let log5 = ReadingLog(
            book: thirdReading,
            date: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
            minutes: 55,
            pageAfterReading: 231
        )

        currentlyReading.logs.append(contentsOf: [log1, log2])
        secondReading.logs.append(log4)
        thirdReading.logs.append(log5)
        finished.logs.append(log3)

        let text1 = BookText(
            book: currentlyReading,
            kind: .excerpt,
            content: "我学会了在沉默中辨认方向，也学会了在漫长的等待里保持耐心。",
            page: 114,
            createdAt: calendar.date(byAdding: .hour, value: -3, to: now) ?? now
        )
        let text2 = BookText(
            book: currentlyReading,
            kind: .note,
            content: "这本书最迷人的地方不是冒险本身，而是那种不解释自己的自由感。",
            page: 118,
            createdAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now
        )
        let text3 = BookText(
            book: finished,
            kind: .excerpt,
            content: "微观机制和宏观结果之间，总隔着无数人的选择、激励和约束。",
            page: 77,
            createdAt: calendar.date(byAdding: .day, value: -5, to: now) ?? now
        )

        currentlyReading.texts.append(contentsOf: [text1, text2])
        finished.texts.append(text3)

        return (
            books: [currentlyReading, secondReading, thirdReading, finished, planned, longBook],
            logs: [log1, log2, log3, log4, log5],
            texts: [text1, text2, text3]
        )
    }
}

struct PreviewHost<Content: View>: View {
    private let data: PreviewLibraryData
    private let content: (PreviewLibraryData) -> Content

    init(@ViewBuilder content: @escaping (PreviewLibraryData) -> Content) {
        self.data = PreviewData.make()
        self.content = content
    }

    var body: some View {
        content(data)
            .modelContainer(data.container)
    }
}
#endif
