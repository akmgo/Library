import SwiftData
import SwiftUI
import WidgetKit

struct WaveEntry: TimelineEntry {
    let date: Date
    let content: String
    let source: String
}

struct WaveProvider: TimelineProvider {
    func placeholder(in context: Context) -> WaveEntry {
        WaveEntry(date: Date(), content: "我们在阅读中寻找的，往往是那些能用文字精确描绘出我们内心模糊感受的瞬间。思想的留白，去阅读中遇见自己。", source: "阅读的意义")
    }

    func getSnapshot(in context: Context, completion: @escaping (WaveEntry) -> ()) {
        Task { @MainActor in
            let entry = fetchRealData(date: Date())
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task { @MainActor in
            var entries: [WaveEntry] = []
            let currentDate = Date()
            
            // ✨ 保持原始结构，但一次性生成 12 张幻灯片（每 5 分钟切换一次），解决不轮播的问题
            for offset in 0 ..< 12 {
                let entryDate = Calendar.current.date(byAdding: .minute, value: offset * 5, to: currentDate)!
                entries.append(fetchRealData(date: entryDate))
            }
            
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        }
    }

    @MainActor
    private func fetchRealData(date: Date) -> WaveEntry {
        // 恢复你最初的调用方式
        let context = SharedDatabase.shared.container.mainContext
        
        do {
            // ✨ 加上 200 条的限制，防止小组件因为内存超载而直接消失崩溃
            var descriptor = FetchDescriptor<Excerpt>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 200
            
            let excerpts = try context.fetch(descriptor)
            
            // ✨ 恢复最安全的内存过滤，避开 #Predicate 导致查不到数据的 Bug
            let bookExcerpts = excerpts.filter { $0.category == .bookExcerpt }

            if let random = bookExcerpts.randomElement() {
                return WaveEntry(
                    date: date,
                    content: random.content,
                    source: random.book?.title ?? "我的阅读笔记"
                )
            }
        } catch {
        }
        
        // 原汁原味的兜底文案
        return WaveEntry(
            date: date,
            content: "保持阅读，保持思考。你的书库中还没有留下摘录，去沉淀第一缕思想吧。",
            source: "我的书房"
        )
    }
}

struct WaveWidgetView: View {
    var entry: WaveProvider.Entry

    var body: some View {
        ZStack(alignment: .topLeading) {
            // ✨ 原版氛围感水印
            Image(systemName: "quote.opening")
                .font(.system(size: 64, weight: .heavy))
                .foregroundColor(Color.indigo.opacity(0.08))
                .offset(x: -8, y: -8)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.content)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundColor(.primary.opacity(0.9))
                    .lineSpacing(6)
                    .lineLimit(4)
                    .minimumScaleFactor(0.9)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    Text("—— \(entry.source)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .containerBackground(for: .widget) {
            #if os(macOS)
            Color(nsColor: .windowBackgroundColor)
            #else
            Color(uiColor: .systemBackground)
            #endif
        }
    }
}

struct ResonanceWaveWidget: Widget {
    let kind: String = "ResonanceWaveWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WaveProvider()) { entry in
            WaveWidgetView(entry: entry)
        }
        .configurationDisplayName("思想共鸣")
        .description("在桌面上随机回顾你曾经留下的阅读摘录。")
        .supportedFamilies([.systemMedium])
    }
}
