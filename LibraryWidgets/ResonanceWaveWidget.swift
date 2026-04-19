import SwiftData
import SwiftUI
import WidgetKit

// MARK: - 数据模型
struct WaveEntry: TimelineEntry {
    let date: Date
    let content: String
    let source: String
}

// MARK: - 数据提供者
struct WaveProvider: TimelineProvider {
    func placeholder(in context: Context) -> WaveEntry {
        WaveEntry(date: Date(), content: "我们在阅读中寻找的，往往是那些能用文字精确描绘出我们内心模糊感受的瞬间。思想的留白，去阅读中遇见自己。", source: "阅读的意义")
    }

    func getSnapshot(in context: Context, completion: @escaping (WaveEntry) -> ()) {
        Task { @MainActor in completion(fetchRealData()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task { @MainActor in
            let entry = fetchRealData()
            // 每 30 分钟随机刷新一次摘录
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    @MainActor
    private func fetchRealData() -> WaveEntry {
        let context = SharedDatabase.shared.container.mainContext
        do {
            let excerpts = try context.fetch(FetchDescriptor<Excerpt>())
            if let random = excerpts.randomElement() {
                return WaveEntry(
                    date: Date(),
                    content: random.content ?? "暂无内容",
                    source: random.book?.title ?? "我的阅读笔记"
                )
            }
        } catch {}
        
        // 兜底空状态
        return WaveEntry(date: Date(), content: "保持阅读，保持思考。你的书库中还没有留下摘录，去沉淀第一缕思想吧。", source: "我的书房")
    }
}

// MARK: - 极简排版视图 (去除了多余标签)
struct WaveWidgetView: View {
    var entry: WaveProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // 核心：最大化展示的摘录文本，去掉了顶部标签，字号放大到 16
            Text(entry.content)
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundColor(.primary.opacity(0.9))
                .lineSpacing(6)
                .lineLimit(4)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 0)
            
            // 底部：书籍来源
            HStack {
                Spacer()
                Text("—— \(entry.source)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
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

// MARK: - 注册组件
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
