import SwiftData
import SwiftUI
import WidgetKit

// 引入特定平台的图像框架
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - 数据模型

/// 中号阅读横幅组件的专属实体。
struct ReadingEntry: TimelineEntry {
    let date: Date
    let hasBook: Bool
    let title: String
    let author: String
    let progress: Double
    let coverData: Data?
}

// MARK: - 数据提供者

/// 提供带有详细书名与百分比横条的中号横幅组件数据。
struct ReadingProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingEntry {
        ReadingEntry(date: Date(), hasBook: true, title: "百年孤独", author: "加西亚·马尔克斯", progress: 45.0, coverData: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingEntry) -> ()) {
        Task { @MainActor in completion(await fetchRealData()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task { @MainActor in
            let entry = await fetchRealData()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    @MainActor
    private func fetchRealData() async -> ReadingEntry {
        let context = SharedDatabase.shared.container.mainContext
        do {
            let allBooks = try context.fetch(FetchDescriptor<Book>())

            // ✨ 使用同样的智能排序逻辑，选出最近在读的一本
            let mostRecentBook = allBooks
                .filter { $0.status == .reading }
                .max { b1, b2 in
                    let date1 = b1.readingRecords?.compactMap(\.date).max() ?? b1.startTime ?? .distantPast
                    let date2 = b2.readingRecords?.compactMap(\.date).max() ?? b2.startTime ?? .distantPast
                    return date1 < date2
                }

            if let book = mostRecentBook {
                return ReadingEntry(
                    date: Date(),
                    hasBook: true,
                    title: book.title ?? "未知书名",
                    author: book.author ?? "未知作者",
                    progress: Double(book.progress),
                    coverData: book.coverData
                )
            }
        } catch {}

        return ReadingEntry(date: Date(), hasBook: false, title: "", author: "", progress: 0, coverData: nil)
    }
}

// MARK: - 全新设计的视图层

/// 中尺寸 (`.systemMedium`) 阅读横幅视图。
/// 布局横向伸展，左侧包含较大的等比封面，右侧包含书本明细与横向水平进度轨。
struct ReadingWidgetView: View {
    var entry: ReadingProvider.Entry

    var body: some View {
        Group {
            if entry.hasBook {
                HStack(spacing: 20) {
                    // ================= 左侧：沉浸式封面 =================
                    Group {
                        if let data = entry.coverData {
                            #if os(macOS)
                            if let nsImage = NSImage(data: data) { Image(nsImage: nsImage).resizable().scaledToFill() } else { FallbackCover() }
                            #else
                            if let uiImage = UIImage(data: data) { Image(uiImage: uiImage).resizable().scaledToFill() } else { FallbackCover() }
                            #endif
                        } else {
                            FallbackCover()
                        }
                    }
                    .frame(width: 90) // 拓宽画幅，视觉冲击力更强
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)

                    // ================= 右侧：现代排版信息区 =================
                    VStack(alignment: .leading, spacing: 0) {
                        // 顶部：高级感标签
                        Text("CURRENT FOCUS")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(.blue.opacity(0.8))
                            .padding(.bottom, 6)

                        // 中间：标题与作者
                        Text(entry.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .padding(.bottom, 2)

                        Text(entry.author)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Spacer()

                        // 底部：巨型数字与线性进度
                        VStack(spacing: 8) {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(Int(entry.progress))")
                                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                                    .foregroundColor(.primary)

                                Text("%")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.secondary)

                                Spacer()

                                Image(systemName: "book.pages.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue.opacity(0.8))
                            }

                            // 自定义纤细流线型进度条
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.primary.opacity(0.08))
                                    Capsule().fill(Color.blue.gradient)
                                        .frame(width: max(0, geo.size.width * (entry.progress / 100.0)), height: 6)
                                }
                            }
                            .frame(height: 5) // 极细设计，非常精致
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                // ================= 空状态设计 =================
                VStack(spacing: 12) {
                    Image(systemName: "book.dashed")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("等待你的翻阅")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .containerBackground(Color.adaptiveWidgetBackground, for: .widget)
    }
}

/// 缺少真实封面图片数据时的极简线框图占位符。
private struct FallbackCover: View {
    var body: some View {
        ZStack {
            Rectangle().fill(Color.secondary.opacity(0.1))
            Image(systemName: "text.book.closed")
                .foregroundColor(.secondary.opacity(0.5))
                .font(.system(size: 28))
        }
    }
}

// MARK: - 注册组件

/// 中号阅读焦点组件配置。
struct ReadingFocusWidget: Widget {
    /// ✨ 必须显式声明全局唯一的 kind 属性，这是小组件的“身份证号”
    let kind: String = "ReadingFocusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadingProvider()) { entry in
            ReadingWidgetView(entry: entry)
        }
        .configurationDisplayName("在读焦点")
        .description("快速查看当前正在阅读的书籍进度。")
        .supportedFamilies([.systemMedium])
    }
}
