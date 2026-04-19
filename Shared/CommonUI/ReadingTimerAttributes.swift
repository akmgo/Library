#if os(iOS)
import Foundation
import ActivityKit

public struct ReadingTimerAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var cycleEndTime: Date
        public var completedCycles: Int
        
        public init(cycleEndTime: Date, completedCycles: Int) {
            self.cycleEndTime = cycleEndTime
            self.completedCycles = completedCycles
        }
    }
    
    public var bookTitle: String
    public var author: String
    public var coverFilePath: String?
    public var bookProgress: Int
    
    public init(bookTitle: String, author: String, coverFilePath: String? = nil, bookProgress: Int = 0) {
        self.bookTitle = bookTitle
        self.author = author
        self.coverFilePath = coverFilePath
        self.bookProgress = bookProgress
    }
}
#endif
