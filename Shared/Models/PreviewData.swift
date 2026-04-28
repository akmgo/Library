import Foundation
import SwiftData
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - 🗄️ 全局预览数据引擎 (Core Engine)

@MainActor
class PreviewData {
    static let shared: ModelContainer = {
        // ✨ 将 Excerpt 和 Note 替换为统一的 BookAnnotation
        let schema = Schema([Book.self, ReadingRecord.self, BookAnnotation.self, UserConfig.self, Snippet.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = container.mainContext
            let calendar = Calendar.current
            let today = Date()
            
            // 1. 初始化设置
            context.insert(UserConfig(dailyReadingGoal: 45, yearlyBookGoal: 60, libraryTargetGoal: 1000))
            
            // 2. 日常摘录 (Snippet)
            let snippetsData = [
                Snippet(title: "鸟鸣涧", content: "人闲桂花落，夜静春山空。\n月出惊山鸟，时鸣春涧中。", author: "王维", dynasty: "唐", category: .poetry),
                Snippet(title: "静夜思", content: "床前明月光，疑是地上霜。\n举头望明月，低头思故乡。", author: "李白", dynasty: "唐", category: .poetry),
                Snippet(title: "如梦令", content: "昨夜雨疏风骤，浓睡不消残酒。\n试问卷帘人，却道海棠依旧。\n知否，知否？应是绿肥红瘦。", author: "李清照", dynasty: "宋", category: .lyric),
                Snippet(title: "青玉案·元夕", content: "东风夜放花千树，更吹落，星如雨。\n宝马雕车香满路。凤箫声动，玉壶光转，一夜鱼龙舞。\n蛾儿雪柳黄金缕，笑语盈盈暗香去。\n众里寻他千百度，蓦然回首，那人却在，灯火阑珊处。", author: "辛弃疾", dynasty: "南宋", category: .lyric),
                Snippet(title: "记承天寺夜游", content: "元丰六年十月十二日夜，解衣欲睡，月色入户，欣然起行。念无与为乐者，遂至承天寺寻张怀民。怀民亦未寝，相与步于中庭。庭下如积水空明，水中藻、荇交横，盖竹柏影也。何夜无月？何处无竹柏？但少闲人如吾两人者耳。", author: "苏轼", dynasty: "北宋", category: .prose),
                Snippet(title: "兰亭集序", content: "永和九年，岁在癸丑，暮春之初，会于会稽山阴之兰亭，修禊事也。群贤毕至，少长咸集。此地有崇山峻岭，茂林修竹，又有清流激湍，映带左右，引以为流觞曲水，列坐其次。虽无丝竹管弦之盛，一觞一咏，亦足以畅叙幽情。是日也，天朗气清，惠风和畅。仰观宇宙之大，俯察品类之盛，所以游目骋怀，足以极视听之娱，信可乐也。", author: "王羲之", dynasty: "东晋", category: .prose),
                Snippet(title: "查拉图斯特拉如是说", content: "每一个不曾起舞的日子，都是对生命的辜负。", author: "尼采", dynasty: "", category: .quote),
                Snippet(title: "米开朗基罗传", content: "世界上只有一种真正的英雄主义，那就是在认清生活的真相之后依然热爱生活。", author: "罗曼·罗兰", dynasty: "", category: .quote),
                Snippet(title: "人间拾遗", content: "你闪闪发亮的同时，也要平平安安。", author: "佚名", dynasty: "", category: .web),
                Snippet(title: "岁末随想", content: "我们都在奔赴各自不同的人生，希望在未来的日子里，你能成为自己想要成为的人，不要轻易被现实打败。山高水长，江湖莫忘。", author: "网络", dynasty: "", category: .web),
                Snippet(title: "星际穿越", content: "唯有爱能凌驾于时间与空间之上。", author: "库珀", dynasty: "", category: .movie),
                Snippet(title: "楚门的世界", content: "假如再也见不到你，\n祝你早安，午安，晚安。", author: "楚门", dynasty: "", category: .movie),
            ]
            snippetsData.forEach { context.insert($0) }

            // 3. 装载书籍
            let bookTitles = [("悉达多", "黑塞"), ("百年孤独", "马尔克斯"), ("三体", "刘慈欣"), ("人类简史", "赫拉利"), ("活着", "余华"), ("理想国", "柏拉图"), ("君主论", "马基雅维利"), ("乌合之众", "勒庞"), ("国富论", "亚当斯密"), ("资本论", "马克思"), ("呐喊", "鲁迅"), ("朝花夕拾", "鲁迅"), ("围城", "钱钟书"), ("边城", "沈从文"), ("茶馆", "老舍"), ("乡土", "费孝通"), ("万历", "黄仁宇"), ("明朝", "当年明月"), ("三国", "罗贯中"), ("红楼", "曹雪芹"), ("白夜行", "东野圭吾"), ("嫌疑人", "东野圭吾"), ("局外人", "加缪"), ("鼠疫", "加缪"), ("城堡", "卡夫卡"), ("变形记", "卡夫卡"), ("老人与海", "海明威"), ("大亨", "菲茨杰拉德"), ("飘", "玛格丽特"), ("简爱", "夏洛蒂")]
            let tagsPool = ["哲学", "历史", "科幻", "文学", "商业", "心理", "传记", "艺术", "社科", "散文"]
            let statuses: BookStatus.AllCases = BookStatus.allCases
            
            var insertedBooks: [Book] = []
            for (index, info) in bookTitles.enumerated() {
                let randomTags = Array(tagsPool.shuffled().prefix(3))
                let assignedStatus = statuses[index % statuses.count]
                
                let cTime = calendar.date(byAdding: .day, value: -Int.random(in: 100...300), to: today)!
                
                var sTime: Date? = nil
                var eTime: Date? = nil
                var prog = 0.0
                
                if assignedStatus == .finished {
                    eTime = calendar.date(byAdding: .day, value: -Int.random(in: 1...30), to: today)
                    sTime = calendar.date(byAdding: .day, value: -Int.random(in: 31...60), to: eTime!)
                    prog = 100.0
                } else if assignedStatus == .reading {
                    sTime = calendar.date(byAdding: .day, value: -Int.random(in: 1...15), to: today)
                    prog = Double.random(in: 5.0...95.0)
                } else if assignedStatus == .abandoned {
                    eTime = calendar.date(byAdding: .day, value: -Int.random(in: 5...20), to: today)
                    prog = Double.random(in: 10.0...40.0)
                }
                
                let book = Book(
                    title: info.0, author: info.1, coverData: generateRandomColorData(),
                    createdAt: cTime, status: assignedStatus, rating: assignedStatus == .finished ? Int.random(in: 3...5) : 0,
                    tags: randomTags, startTime: sTime, endTime: eTime, progress: prog
                )
                context.insert(book)
                insertedBooks.append(book)
            }
            
            // ✨ 4. 挂载摘录与笔记 (统一使用 BookAnnotation)
            let targetBooks = Array(insertedBooks.prefix(5))
            for i in 0..<10 {
                let targetBook = targetBooks[i % targetBooks.count]
                
                context.insert(BookAnnotation(
                    content: "这是来自《\(targetBook.title)》的第 \(i + 1) 条高光摘录。文字充满了力量，引人深思。",
                    type: .excerpt,
                    createdAt: calendar.date(byAdding: .day, value: -Int.random(in: 1...10), to: today)!,
                    book: targetBook
                ))
                
                context.insert(BookAnnotation(
                    content: "关于《\(targetBook.title)》的第 \(i + 1) 条思考。隐喻非常精妙，让我有了全新的视角。",
                    type: .note,
                    createdAt: calendar.date(byAdding: .day, value: -Int.random(in: 1...10), to: today)!,
                    book: targetBook
                ))
            }
            
            // 5. 生成打卡记录
            let readingBooks = insertedBooks.filter { $0.status == .reading || $0.status == .finished }
            for i in 0..<90 {
                if Bool.random() && Bool.random() || Bool.random() {
                    let record = ReadingRecord(date: calendar.date(byAdding: .day, value: -i, to: today)!, book: readingBooks.randomElement()!)
                    record.readingDuration = TimeInterval(Int.random(in: 15...120) * 60)
                    context.insert(record)
                }
            }
            return container
        } catch {
            fatalError("无法创建预览数据库: \(error)")
        }
    }()
    
    static var mockBook: Book { allMockBooks.first { $0.status == .reading } ?? allMockBooks.first! }
    static var allMockBooks: [Book] { try! shared.mainContext.fetch(FetchDescriptor<Book>(sortBy: [SortDescriptor(\.title)])) }
    static var allMockRecords: [ReadingRecord] { try! shared.mainContext.fetch(FetchDescriptor<ReadingRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])) }
    static var mockConfig: UserConfig { try! shared.mainContext.fetch(FetchDescriptor<UserConfig>()).first! }
    static var allMockSnippets: [Snippet] { try! shared.mainContext.fetch(FetchDescriptor<Snippet>(sortBy: [SortDescriptor(\.addedDate, order: .reverse)])) }
    
    // ✨ 统一暴露所有批注
    static var allMockAnnotations: [BookAnnotation] {
        try! shared.mainContext.fetch(FetchDescriptor<BookAnnotation>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
    }

    private static func generateRandomColorData() -> Data? {
        let size = CGSize(width: 100, height: 150)
        let r = CGFloat.random(in: 0.2...0.8); let g = CGFloat.random(in: 0.2...0.8); let b = CGFloat.random(in: 0.2...0.8)
        #if os(iOS)
        UIGraphicsBeginImageContext(size); let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor(red: r, green: g, blue: b, alpha: 1.0).cgColor); context.fill(CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return img?.jpegData(compressionQuality: 0.5)
        #elseif os(macOS)
        let img = NSImage(size: size); img.lockFocus(); let color = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        color.drawSwatch(in: NSRect(origin: .zero, size: size)); img.unlockFocus(); return img.tiffRepresentation
        #endif
    }
}

extension PreviewData {
    static var mockMomentumChartData: (points: [MomentumDataPoint], total: Int) {
        let cal = Calendar.current; let today = cal.startOfDay(for: Date())
        var points: [MomentumDataPoint] = []; var totalMins = 0.0
        var buckets: [Date: Double] = [:]
        for i in 0..<14 { buckets[cal.date(byAdding: .day, value: -i, to: today)!] = 0.0 }
        
        for record in allMockRecords {
            let recordDate = cal.startOfDay(for: record.date)
            if buckets.keys.contains(recordDate) {
                let mins = record.readingDuration / 60.0
                buckets[recordDate]! += mins; totalMins += mins
            }
        }
        for i in (0..<14).reversed() {
            let date = cal.date(byAdding: .day, value: -i, to: today)!
            points.append(MomentumDataPoint(date: date, minutes: i == 0 && buckets[date]! == 0 ? 20.0 : buckets[date]!, isToday: i == 0))
        }
        return (points, Int(totalMins))
    }
    
    static var mockHeatmapData: (columns: [[HeatmapDataPoint]], activeDays: Int) {
        var cal = Calendar.current; cal.firstWeekday = 2; let today = cal.startOfDay(for: Date())
        var durs: [Date: TimeInterval] = [:]; var activeDays = 0
        for r in allMockRecords { durs[cal.startOfDay(for: r.date), default: 0] += r.readingDuration }
        
        let daysToSubtract = (cal.component(.weekday, from: today) + 5) % 7
        let start = cal.date(byAdding: .weekOfYear, value: -52, to: cal.date(byAdding: .day, value: -daysToSubtract, to: today)!)!
        
        var cols = [[HeatmapDataPoint]]()
        for w in 0..<53 {
            var col = [HeatmapDataPoint]()
            for d in 0..<7 {
                let date = cal.date(byAdding: .day, value: w * 7 + d, to: start)!
                let dur = durs[date] ?? 0; let isFuture = date > today; var intensity = 0.0
                if !isFuture, dur > 0 { intensity = min((dur / 3600.0) * 0.7 + 0.3, 1.0); activeDays += 1 }
                col.append(HeatmapDataPoint(date: date, intensity: intensity, isFuture: isFuture, tooltip: isFuture ? "未到" : (dur == 0 ? "未打卡" : "专注 \(Int(dur / 60)) 分钟")))
            }
            cols.append(col)
        }
        return (cols, activeDays)
    }
    
    static var mockResonanceData: [ResonanceDataPoint] {
        // ✨ 改为过滤 Annotation 里的摘录
        let excerpts = allMockAnnotations.filter { $0.type == .excerpt }
        if excerpts.isEmpty { return [ResonanceDataPoint(content: "思想的留白，去阅读中遇见自己。", source: "系统寄语")] }
        return excerpts.map { ResonanceDataPoint(content: $0.content, source: $0.book?.title ?? "札记") }
    }
    
    static var mockQueueBooksData: [QueueBookDataPoint] {
        Array(allMockBooks.filter { $0.status == .wantToRead }.prefix(4)).map { QueueBookDataPoint(id: $0.id, title: $0.title, author: $0.author, coverData: $0.coverData) }
    }
    
    static var mockSpectrumData: [SpectrumDataPoint] {
        var counts: [String: Double] = [:]
        for b in allMockBooks { for t in b.tags { counts[t, default: 0] += 1 } }
        let top5 = counts.sorted { $0.value > $1.value }.prefix(5)
        let top5Total = top5.reduce(0.0) { $0 + $1.value }
        guard top5Total > 0 else { return [] }
        
        let colors: [Color] = [.purple, .indigo, .teal, .orange, .blue]
        return top5.enumerated().map { index, element in
            SpectrumDataPoint(tagName: element.key, percentage: (element.value / top5Total) * 100.0, color: colors[index % colors.count])
        }
    }
}
