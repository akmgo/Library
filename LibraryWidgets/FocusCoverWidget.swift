import WidgetKit
import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - ✨ 双端兼容背景色扩展

/// 提供小组件跨平台底层安全背景色的扩展支持。
extension Color {
    static var adaptiveWidgetBackground: Color {
        #if os(iOS)
        return Color(uiColor: .systemBackground)
        #elseif os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color.clear
        #endif
    }
}

// MARK: - 1. 专属数据模型

/// 小组件时间线实体，携带在读书籍的详细数据。
struct FocusHeroEntry: TimelineEntry {
    let date: Date
    let bookTitle: String
    let bookAuthor: String
    let coverData: Data?
    let bookProgress: Double
    let todayMinutes: Int
    let hasBook: Bool // 标识是否真的有在读书籍，用于空状态渲染
}

// MARK: - 2. 专属数据引擎

/// 获取最近活跃的一本在读书籍及其今日阅读数据。
struct FocusHeroProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusHeroEntry { mockEntry() }
    
    func getSnapshot(in context: Context, completion: @escaping (FocusHeroEntry) -> ()) {
        Task { @MainActor in completion(await fetchRealData()) }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task { @MainActor in
            let entry = await fetchRealData()
            // 在读书籍的数据（特别是进度和时长）可能会变，设置 15 分钟刷新一次
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }
    
    @MainActor
    private func fetchRealData() async -> FocusHeroEntry {
        let context = SharedDatabase.shared.container.mainContext
        do {
            let allBooks = try context.fetch(FetchDescriptor<Book>())
            // 获取最近在读的书
            let mostRecentBook = allBooks
                .filter { $0.status == .reading }
                .max { b1, b2 in
                    let date1 = b1.readingRecords?.compactMap(\.date).max() ?? b1.startTime ?? .distantPast
                    let date2 = b2.readingRecords?.compactMap(\.date).max() ?? b2.startTime ?? .distantPast
                    return date1 < date2
                }
            
            if let book = mostRecentBook {
                // 计算今日阅读时长
                let today = Calendar.current.startOfDay(for: Date())
                var todayMins = 0
                if let record = book.readingRecords?.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
                    todayMins = Int(record.readingDuration / 60)
                }
                
                return FocusHeroEntry(
                    date: Date(),
                    bookTitle: book.title,
                    bookAuthor: book.author,
                    coverData: book.coverData,
                    bookProgress: book.progress,
                    todayMinutes: todayMins,
                    hasBook: true
                )
            }
        } catch {
            print("❌ FocusHeroWidget 读取失败: \(error)")
        }
        return FocusHeroEntry(date: Date(), bookTitle: "", bookAuthor: "", coverData: nil, bookProgress: 0, todayMinutes: 0, hasBook: false)
    }
    
    private func mockEntry() -> FocusHeroEntry {
        FocusHeroEntry(date: Date(), bookTitle: "百年孤独", bookAuthor: "马尔克斯", coverData: nil, bookProgress: 42.0, todayMinutes: 45, hasBook: true)
    }
}

// MARK: - 3. UI 视图 (纯净展示板，移除交互)

/// 专为小组件适配的无交互只读轨道。
private struct WidgetTrackBar: View {
    let value: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
                Capsule()
                    .fill(color)
                    .frame(width: max(0, geo.size.width * value))
            }
        }
        .frame(height: 8) // 小组件中适当缩小高度
    }
}

/// 适配 `.systemMedium` 中号尺寸的在读焦点视图。
struct FocusHeroWidgetView: View {
    var entry: FocusHeroEntry
    
    var body: some View {
        if entry.hasBook {
            // 动态计算当日时长的视觉上限（类似呼吸感扩容算法，展示用）
            let maxMins = entry.todayMinutes == 0 ? 10 : ((entry.todayMinutes / 10) + 1) * 10
            let normalizedProgress = min(max(entry.bookProgress / 100.0, 0), 1.0)
            let normalizedTime = min(max(Double(entry.todayMinutes) / Double(maxMins), 0), 1.0)
            
            HStack(alignment: .center, spacing: 16) {
                // ================= 1. 左侧：封面 =================
                GeometryReader { geo in
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.gray.opacity(0.15))
                        
                        if let data = entry.coverData {
                            #if os(iOS)
                            if let platformImage = UIImage(data: data) {
                                Image(uiImage: platformImage).resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped()
                            }
                            #elseif os(macOS)
                            if let platformImage = NSImage(data: data) {
                                Image(nsImage: platformImage).resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped()
                            }
                            #endif
                        } else {
                            Image(systemName: "book.closed.fill").foregroundColor(.orange.opacity(0.8)).font(.system(size: 24))
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                }
                .frame(width: 90) // 小组件固定封面宽度
                
                // ================= 2. 右侧：信息与双轨区 =================
                VStack(alignment: .leading, spacing: 0) {
                    Text("CURRENTLY READING")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.blue)
                        .tracking(1.5)
                        .padding(.bottom, 4)
                    
                    Text(entry.bookTitle)
                        .font(.system(size: 20, weight: .heavy, design: .serif))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    
                    Text(entry.bookAuthor)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .padding(.top, 2)
                    
                    Spacer()
                    
                    // ================= 底层双轨展示 =================
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .bottom) {
                            Text("\(Int(entry.bookProgress))%")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(entry.todayMinutes)m")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(spacing: 6) {
                            WidgetTrackBar(value: normalizedProgress, color: .blue)
                            WidgetTrackBar(value: normalizedTime, color: .mint)
                        }
                    }
                }
            }
            .containerBackground(Color.adaptiveWidgetBackground, for: .widget)
        } else {
            // 空状态
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .frame(width: 90)
                        .background(Color.secondary.opacity(0.02))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Image(systemName: "book.closed")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.secondary.opacity(0.4))
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("CURRENTLY READING")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.3))
                        .tracking(1.5)
                        .padding(.bottom, 4)
                    Text("虚位以待")
                        .font(.system(size: 20, weight: .heavy, design: .serif))
                        .foregroundColor(.primary.opacity(0.4))
                        .lineLimit(1)
                    Text("去书库中挑选一本吧")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.5))
                        .lineLimit(1)
                        .padding(.top, 2)
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .bottom) {
                            Text("0%").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.secondary.opacity(0.3))
                            Spacer()
                            Text("0m").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.secondary.opacity(0.3))
                        }
                        VStack(spacing: 6) {
                            WidgetTrackBar(value: 0, color: .secondary.opacity(0.2))
                            WidgetTrackBar(value: 0, color: .secondary.opacity(0.2))
                        }
                    }
                }
            }
            .containerBackground(Color.adaptiveWidgetBackground, for: .widget)
        }
    }
}

// MARK: - 4. 组件注册入口

/// 桌面在读焦点小组件配置。
struct FocusHeroWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FocusHeroWidget", provider: FocusHeroProvider()) { entry in
            FocusHeroWidgetView(entry: entry)
        }
        .configurationDisplayName("在读焦点")
        .description("展示当前在读书籍及其双轨阅读进度。")
        .supportedFamilies([.systemMedium]) // ✨ 强制变更为中号，以提供足够空间展示双轨
    }
}

#Preview("在读焦点双轨版", as: .systemMedium) {
    FocusHeroWidget()
} timeline: {
    FocusHeroEntry(date: Date(), bookTitle: "乌合之众", bookAuthor: "古斯塔夫·勒庞", coverData: nil, bookProgress: 68.5, todayMinutes: 35, hasBook: true)
    FocusHeroEntry(date: Date(), bookTitle: "", bookAuthor: "", coverData: nil, bookProgress: 0, todayMinutes: 0, hasBook: false)
}
