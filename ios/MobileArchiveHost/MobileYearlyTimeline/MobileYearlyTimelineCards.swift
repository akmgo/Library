#if os(iOS)
import SwiftUI
import SwiftData

// MARK: - 📱 横竖屏双引擎时间轴组件

/// 单个年度轨迹节点的封装器。
///
/// 根据外层的 `@Environment(\.verticalSizeClass)`，智能判定输出：
/// - **横屏版**：Z 字形交错，中轴居中。
/// - **竖屏版**：传统列表形，中轴靠左。
struct MobileTimelineRowView: View {
    let book: Book
    let index: Int
    let isLast: Bool
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        let isLandscape = verticalSizeClass == .compact
        let isLeft = index % 2 == 0
        
        if isLandscape {
            // ================= 横屏：左右交错对齐 =================
            HStack(spacing: 0) {
                Group {
                    if isLeft {
                        NavigationLink(destination: MobileBookDetailView(book: book)) { MobileTimelineCardView(book: book) }.buttonStyle(.plain).padding(.trailing, 20)
                    } else {
                        MobileTimelineDateView(book: book, isLeft: true).padding(.trailing, 20)
                    }
                }.frame(maxWidth: .infinity, alignment: .trailing)
                
                // 中心轴线
                VStack(spacing: 0) {
                    ZStack {
                        Circle().fill(Color(uiColor: .systemGroupedBackground)).frame(width: 14, height: 14)
                        Circle().stroke(Color.blue.opacity(0.6), lineWidth: 3)
                    }.frame(height: 28)
                    Rectangle().fill(isLast ? LinearGradient(colors: [Color.blue.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [Color.blue.opacity(0.3)], startPoint: .top, endPoint: .bottom)).frame(width: 2)
                }
                
                Group {
                    if isLeft {
                        MobileTimelineDateView(book: book, isLeft: false).padding(.leading, 20)
                    } else {
                        NavigationLink(destination: MobileBookDetailView(book: book)) { MobileTimelineCardView(book: book) }.buttonStyle(.plain).padding(.leading, 20)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 40).padding(.bottom, 40)
            
        } else {
            // ================= 竖屏：经典的居左时间轴 =================
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle().fill(Color(uiColor: .systemGroupedBackground)).frame(width: 14, height: 14)
                        Circle().stroke(Color.blue.opacity(0.6), lineWidth: 3)
                    }.frame(height: 28)
                    Rectangle().fill(isLast ? LinearGradient(colors: [Color.blue.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [Color.blue.opacity(0.3)], startPoint: .top, endPoint: .bottom)).frame(width: 2)
                }
                .padding(.leading, 20)
                
                VStack(alignment: .leading, spacing: 12) {
                    MobileTimelineDateView(book: book, isLeft: false)
                    NavigationLink(destination: MobileBookDetailView(book: book)) {
                        MobileTimelineCardView(book: book)
                    }.buttonStyle(PlainButtonStyle())
                }
                .padding(.bottom, 40).padding(.trailing, 20)
            }
        }
    }
}

/// 时间轴节点对侧的短日期展示视图。支持对高分书籍弹射 `🔥 强推` 徽章。
struct MobileTimelineDateView: View {
    let book: Book
    let isLeft: Bool
    
    private var dateStr: String {
        guard let date = book.endTime else { return "未知" }
        let formatter = DateFormatter(); formatter.dateFormat = "M月d日"; return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if isLeft { Spacer() }
            Text(dateStr).font(.system(size: 20, weight: .bold, design: .rounded)).tracking(1).foregroundColor(.secondary)
            if (book.rating ?? 0) >= 4 {
                // ✨ 橙色火焰强推徽章
                HStack(spacing: 4) { Image(systemName: "flame.fill").font(.system(size: 11)); Text("强推").font(.system(size: 11, weight: .bold)) }
                    .foregroundColor(.orange).padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15)).clipShape(Capsule())
            }
            if !isLeft { Spacer() }
        }
    }
}

// MARK: - 📱 子组件：原生时间轴多彩卡片

/// 展示书籍主要数据的时间轴实体卡片。
///
/// **内含元素：**
/// - 书皮封面图。
/// - 五角星评分控件与特定金句。
/// - 指示这本“旅途”花了多久完成的通行证模块 (`MobileJourneyTicket`)。
struct MobileTimelineCardView: View {
    let book: Book
    let ratingTexts = ["", "一星毒草", "二星平庸", "三星粮草", "四星推荐", "改变人生"]
    
    var body: some View {
        let safeTitle = book.title ?? "未知书名"
        let safeAuthor = book.author ?? "未知作者"
        let safeRating = book.rating ?? 0
        let safeTags = book.tags ?? []
        
        ZStack(alignment: .leading) {
            // 背景底色与右上角极具辨识度的巨型虚化引号水印
            GeometryReader { geo in
                ZStack { Image(systemName: "quote.opening").font(.system(size: 80, weight: .bold)).foregroundColor(Color.blue.opacity(0.03)).position(x: geo.size.width - 20, y: 20) }
            }.clipShape(RoundedRectangle(cornerRadius: 16))
            
            HStack(alignment: .top, spacing: 16) {
                LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                    .frame(width: 80, height: 120).clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                    .shadow(color: Color.black.opacity(0.1), radius: 6, y: 3)
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(safeTitle).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary).lineLimit(1).layoutPriority(1)
                        Spacer(minLength: 12)
                        Text(safeAuthor).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary).lineLimit(1).fixedSize(horizontal: true, vertical: false).layoutPriority(0)
                    }.frame(maxWidth: .infinity)
                    
                    Spacer()
                    
                    // 评分模块
                    if safeRating > 0 {
                        HStack(spacing: 2) {
                            // ✨ 金色星星
                            ForEach(1 ... 5, id: \.self) { i in Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(i <= safeRating ? .yellow : Color.secondary.opacity(0.2)) }
                            Text(safeRating < ratingTexts.count ? ratingTexts[safeRating] : "").font(.system(size: 10, weight: .bold)).foregroundColor(.orange).padding(.leading, 4)
                            if safeRating == 5 { Image(systemName: "crown.fill").font(.system(size: 10)).foregroundColor(.orange) }
                        }
                    } else { Color.clear.frame(height: 12) }
                    
                    Spacer()
                    
                    // 标签模块
                    if !safeTags.isEmpty {
                        HStack(spacing: 6) {
                            // ✨ Tag 采用靛青色调，摆脱灰暗
                            ForEach(Array(safeTags.prefix(3)), id: \.self) { tag in
                                Text(tag).font(.system(size: 9, weight: .bold)).foregroundColor(.indigo)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(Color.indigo.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    } else { Color.clear.frame(height: 15) }
                    
                    Spacer()
                    MobileJourneyTicket(book: book)
                }
                .frame(height: 120)
            }.padding(16)
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }
}

// ✨ 移动专属：超微缩青色护照通行证

/// 像一张航班登机牌一样，用极小的空间描述出这本数从拿起到放下跨越的日历时间。
struct MobileJourneyTicket: View {
    let book: Book
    var body: some View {
        let days = calculateDays(start: book.startTime, end: book.endTime)
        
        HStack(spacing: 0) {
            Text(formatShortDate(book.startTime)).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.secondary)
            HStack(spacing: 4) {
                Circle().fill(Color.teal).frame(width: 4, height: 4)
                Rectangle().fill(Color.teal.opacity(0.5)).frame(height: 1)
                
                Text("\(days)天").font(.system(size: 9, weight: .bold)).foregroundColor(.teal).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(Color.teal.opacity(0.15)).clipShape(Capsule())
                
                Rectangle().fill(Color.teal.opacity(0.5)).frame(height: 1)
                Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundColor(.teal)
            }.padding(.horizontal, 8)
            Text(formatShortDate(book.endTime)).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func formatShortDate(_ date: Date?) -> String {
        guard let d = date else { return "未知" }; let formatter = DateFormatter(); formatter.dateFormat = "M.d"; return formatter.string(from: d)
    }

    private func calculateDays(start: Date?, end: Date?) -> Int {
        guard let s = start, let e = end else { return 1 }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: s)
        let endOfDay = calendar.startOfDay(for: e)
        let diff = calendar.dateComponents([.day], from: startOfDay, to: endOfDay).day ?? 0
        return max(1, diff + 1)
    }
}
#endif
