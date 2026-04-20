import Foundation
import SwiftUI
import SwiftData

/// 专为 Xcode SwiftUI 预览 (Canvas) 提供的全局内存数据库单例。
///
/// **职责：**
/// 避免在 UI 预览时污染用户沙盒里的真实数据库。
/// 它启动时会强制指定 `isStoredInMemoryOnly: true`，并在初始化阶段
/// 灌入大量的模拟假数据 (Mock Data)，包括复杂的图表历史记录和模型关系，
/// 让开发者在写 UI 时能立刻看到组件填满数据后的真实视觉效果。
@MainActor
class PreviewData {
    
    /// 全局唯一的预览内存环境容器。
    /// 它的初始化过程是线程安全的，并且仅在第一次访问时生成并填入所有假数据。
    static let shared: ModelContainer = {
        let schema = Schema([Book.self, ReadingRecord.self, Note.self, Excerpt.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = container.mainContext
            
            // 为了让“年度阅读轨迹”有数据，我们动态获取今年年份
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd"
            let currentYear = String(Calendar.current.component(.year, from: Date()))
            
            // ==========================================
            // 2. 批量装载模拟书籍记录
            // ==========================================
            let book1 = Book(title: "悉达多", author: "赫尔曼·黑塞", status: .reading, tags: ["哲学", "文学"])
            let book2 = Book(title: "百年孤独", author: "加西亚·马尔克斯", status: .unread, tags: ["魔幻现实"])
            let book3 = Book(title: "三体", author: "刘慈欣", status: .unread, tags: ["科幻大作"])
            let book4 = Book(title: "人类简史", author: "尤瓦尔·赫拉利", status: .finished, rating: 4, tags: ["历史", "人类学"], startTime: formatter.date(from: "\(currentYear)/02/01"), endTime: formatter.date(from: "\(currentYear)/02/20"))
            let book5 = Book(title: "活着", author: "余华", status: .finished, rating: 5, tags: ["经典"], startTime: formatter.date(from: "\(currentYear)/01/10"), endTime: formatter.date(from: "\(currentYear)/03/15"))
            let book6 = Book(title: "理想国", author: "柏拉图", status: .finished, rating: 5, tags: ["哲学", "政治"], startTime: formatter.date(from: "\(currentYear)/04/01"), endTime: formatter.date(from: "\(currentYear)/04/10"))
            
            context.insert(book1)
            context.insert(book2)
            context.insert(book3)
            context.insert(book4)
            context.insert(book5)
            context.insert(book6)
            
            // ==========================================
            // 3. 模拟挂载复杂的反向层级关系 (摘录与笔记)
            // ==========================================
            let excerpt1 = Excerpt(content: "知识可以传授，但智慧不能。人们可以寻见智慧，在生命中体现出智慧，以智慧自强，以智慧来创造奇迹，但人们不可能去传授智慧。")
            let note1 = Note(content: "黑塞通过悉达多一生的求道之旅，展现了人如何在体验世俗极致后，最终与万物和解的过程。太震撼了。")
            context.insert(excerpt1)
            context.insert(note1)
            
            // ==========================================
            // 4. 伪造打卡热力图与时间动能数据
            // ==========================================
            let cal = Calendar.current
            let today = Date()
            for i in 0..<30 {
                // 以 70% 的随机概率生成某天读过书的记录
                if Bool.random() {
                    let pastDate = cal.date(byAdding: .day, value: -i, to: today)!
                    let record = ReadingRecord(date: pastDate, book: book1)
                    // 随机生成 15 - 90 分钟的阅读时长
                    record.readingDuration = TimeInterval(Int.random(in: 15...90) * 60)
                    context.insert(record)
                }
            }
            
            return container
        } catch {
            fatalError("无法创建预览数据库: \(error)")
        }
    }()
    
    // MARK: - 快捷访问属性
    
    /// 提供便捷抓取：获取内存库中的第一本书（常用于需要独立 `Book` 传参的小卡片 UI 预览）。
    static var mockBook: Book {
        let fetchDescriptor = FetchDescriptor<Book>()
        let books = try! shared.mainContext.fetch(fetchDescriptor)
        return books.first!
    }
    
    /// 提供便捷抓取：获取内存库中完整生成的乱序书籍列表（常用于画廊、列表或大盘统计视图预览）。
    static var allMockBooks: [Book] {
        let fetchDescriptor = FetchDescriptor<Book>()
        return try! shared.mainContext.fetch(fetchDescriptor)
    }
}
