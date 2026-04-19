import WidgetKit
import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - ✨ 双端兼容背景色扩展 (写在一处，处处可用)
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

// MARK: - 专属数据模型
struct FocusCoverEntry: TimelineEntry {
    let date: Date
    let bookCoverData: Data?
    let bookProgress: Int
}

// MARK: - 专属数据引擎
struct FocusCoverProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusCoverEntry { mockEntry() }
    
    func getSnapshot(in context: Context, completion: @escaping (FocusCoverEntry) -> ()) {
        Task { @MainActor in completion(await fetchRealData()) }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task { @MainActor in
            let entry = await fetchRealData()
            let timeline = Timeline(entries: [entry], policy: .never)
            completion(timeline)
        }
    }
    
    @MainActor
    private func fetchRealData() async -> FocusCoverEntry {
        let context = SharedDatabase.shared.container.mainContext
        do {
            let allBooks = try context.fetch(FetchDescriptor<Book>())
            let mostRecentBook = allBooks
                .filter { $0.status == .reading }
                .max { b1, b2 in
                    let date1 = b1.readingRecords?.compactMap(\.date).max() ?? b1.startTime ?? .distantPast
                    let date2 = b2.readingRecords?.compactMap(\.date).max() ?? b2.startTime ?? .distantPast
                    return date1 < date2
                }
            
            if let book = mostRecentBook {
                return FocusCoverEntry(
                    date: Date(),
                    bookCoverData: book.coverData,
                    bookProgress: book.progress
                )
            }
        } catch {
            print("❌ FocusCoverWidget 读取失败: \(error)")
        }
        return FocusCoverEntry(date: Date(), bookCoverData: nil, bookProgress: 0)
    }
    
    private func mockEntry() -> FocusCoverEntry {
        FocusCoverEntry(date: Date(), bookCoverData: nil, bookProgress: 35)
    }
}

// MARK: - UI 视图
struct FocusCoverWidgetView: View {
    var entry: FocusCoverEntry
    
    var body: some View {
        HStack(spacing: 12) {
            
            // ================= 左侧：沉浸式大封面 =================
            GeometryReader { geo in
                ZStack {
                    // 下层：占位背景
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.gray.opacity(0.15))
                    
                    // 上层：图片内容
                    if let data = entry.bookCoverData {
                        #if os(iOS)
                        if let platformImage = UIImage(data: data) {
                            Image(uiImage: platformImage)
                                .resizable()
                                .scaledToFill()
                                // ✨ 核心防越界 1：死死锁住图片尺寸，绝不允许它向外撑开
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped() // 裁掉多余像素
                        } else {
                            Image(systemName: "book.closed.fill")
                                .foregroundColor(.orange.opacity(0.8))
                                .font(.system(size: 36))
                        }
                        #elseif os(macOS)
                        if let platformImage = NSImage(data: data) {
                            Image(nsImage: platformImage)
                                .resizable()
                                .scaledToFill()
                                // ✨ 核心防越界 1：死死锁住图片尺寸
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        } else {
                            Image(systemName: "book.closed.fill")
                                .foregroundColor(.orange.opacity(0.8))
                                .font(.system(size: 36))
                        }
                        #endif
                    } else {
                        Image(systemName: "book.closed.fill")
                            .foregroundColor(.orange.opacity(0.8))
                            .font(.system(size: 36))
                    }
                }
                // ✨ 核心防越界 2：将 ZStack 的最终容器也锁在安全区内
                .frame(width: geo.size.width, height: geo.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
            }
            .frame(maxWidth: .infinity)
            
            // ================= 右侧：垂直能量槽 =================
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        Capsule().fill(Color.orange.opacity(0.15))
                        Capsule()
                            .fill(Color.orange.gradient)
                            .frame(height: geo.size.height * CGFloat(entry.bookProgress) / 100.0)
                    }
                }
                .frame(width: 16)
                
                Text("\(entry.bookProgress)%")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.orange)
                    .minimumScaleFactor(0.8)
                    // ✨ 视觉校准：略微抵消系统字体的底部留白，让封面和数字形成绝对水平的下边框
                    .padding(.bottom, 2)
            }
            .padding(.top, 2)
            .frame(width: 32)
        }
        .containerBackground(Color.adaptiveWidgetBackground, for: .widget)
    }
}
// MARK: - 组件注册入口
struct FocusCoverWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FocusCoverWidget", provider: FocusCoverProvider()) { entry in
            FocusCoverWidgetView(entry: entry)
        }
        .configurationDisplayName("在读焦点 (小)")
        .description("展示当前在读书籍封面与极简进度。")
        .supportedFamilies([.systemSmall])
    }
}

#Preview("在读焦点", as: .systemSmall) {
    FocusCoverWidget()
} timeline: {
    FocusCoverEntry(date: Date(), bookCoverData: nil, bookProgress: 68)
}
