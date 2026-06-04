import Foundation

enum ReadingLogMetrics {
    static func pagesReadByLogID(for logs: [ReadingLog]) -> [UUID: Int] {
        let logsByBookID = Dictionary(grouping: logs.compactMap { log -> ReadingLog? in
            log.book == nil ? nil : log
        }) { log in
            log.book?.id
        }

        var result: [UUID: Int] = [:]
        for (_, bookLogs) in logsByBookID {
            var previousMaxPage = 0
            for log in bookLogs.sorted(by: { $0.date < $1.date }) where log.pageAfterReading > 0 {
                let delta = log.pageAfterReading - previousMaxPage
                if delta > 0 {
                    result[log.id] = delta
                }
                previousMaxPage = max(previousMaxPage, log.pageAfterReading)
            }
        }
        return result
    }

    static func refreshCurrentPage(for book: Book?, excluding deletedID: UUID? = nil) {
        guard let book else { return }
        let latestPage = book.logs
            .filter { $0.id != deletedID && $0.pageAfterReading > 0 }
            .max { lhs, rhs in lhs.date < rhs.date }?
            .pageAfterReading ?? 0
        book.currentPage = latestPage
    }
}
