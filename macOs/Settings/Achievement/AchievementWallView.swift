#if os(macOS)
import SwiftUI
import SwiftData

// MARK: - 稀有度与材质定义

/// 定义成就徽章的阶级与材质表现。
///
/// 不同的阶级将直接影响 UI 上的渐变配色、发光特效及文字对比度。
enum BadgeRarity: String {
    case bronze = "青铜", silver = "白银", gold = "耀金", diamond = "紫钻", obsidian = "黑曜"
    
    /// 对应的 SwiftUI 原生渐变色彩盘。
    var baseColors: [Color] {
        switch self {
        case .bronze: return [Color(red: 0.8, green: 0.5, blue: 0.3), Color(red: 0.5, green: 0.3, blue: 0.1)]
        case .silver: return [Color(white: 0.9), Color(white: 0.6)]
        case .gold:   return [Color.yellow, Color.orange]
        case .diamond: return [Color.purple, Color.indigo, Color.blue]
        case .obsidian: return [Color.black, Color(white: 0.2)]
        }
    }
    /// 保证深浅模式下文字对比度的文字安全色。
    var textColor: Color { self == .silver ? .primary : .white }
}

// MARK: - 核心判定引擎

/// 定义成就的静态元数据与动态判定逻辑闭包。
struct BadgeDef: Identifiable {
    let id: Int
    let title: String
    let description: String
    let icon: String
    let rarity: BadgeRarity
    /// 接收当前应用所有有效数据包，执行业务逻辑判定，若达成条件则返回解锁时间戳。
    let conditionCheck: (AchievementData) -> Date?
}

/// 在执行成就判定时封装传递的数据胶囊。
struct AchievementData {
    let books: [Book]
    let records: [ReadingRecord]
    let excerpts: [Excerpt]
    let notes: [Note]
}

/// 掌管 50 项硬核阅读成就解锁判定的核心枢纽。
///
/// **架构特性：**
/// 这是一个纯数据驱动的单例类，它内部维护了一套庞大而严谨的判定法则（基于函数式的高阶过滤与计算）。
/// 从最基本的“看完一本书”，到严苛的“书库仅有 1 本书处于在读状态”，乃至恐怖的“累计读完 500 本书”，
/// 全量逻辑都在此处收口。
class AchievementEngine {
    static let shared = AchievementEngine()
    
    /// 全部 50 枚成就徽章的定义与算法集合。
    let allBadges: [BadgeDef] = [
        // =======================================
        // 维度一：极简约束 (1-10)
        // =======================================
        BadgeDef(id: 1, title: "专一之境", description: "书库中有且仅有 1 本书处于在读状态。", icon: "target", rarity: .bronze) { d in
            d.books.filter { $0.status == .reading }.count == 1 ? Date() : nil
        },
        BadgeDef(id: 2, title: "克制的欲望", description: "想读清单达到自我约束上限 (4本)。", icon: "hand.raised.fill", rarity: .bronze) { d in
            d.books.filter { $0.isWantToRead }.count >= 4 ? Date() : nil
        },
        BadgeDef(id: 3, title: "断舍离", description: "书库中没有任何想读的书，且至少读完 1 本。", icon: "leaf.fill", rarity: .silver) { d in
            (d.books.filter { $0.isWantToRead }.isEmpty && d.books.contains { $0.status == .finished }) ? Date() : nil
        },
        BadgeDef(id: 4, title: "清空杂念", description: "所有录入的书籍皆已读完，无任何未读或在读。", icon: "wind", rarity: .silver) { d in
            (!d.books.isEmpty && d.books.allSatisfy { $0.status == .finished }) ? Date() : nil
        },
        BadgeDef(id: 5, title: "从一而终", description: "累计读完 3 本书，且当前在读不超过 1 本。", icon: "lock.fill", rarity: .gold) { d in
            (d.books.filter { $0.status == .finished }.count >= 3 && d.books.filter { $0.status == .reading }.count <= 1) ? Date() : nil
        },
        BadgeDef(id: 6, title: "心无旁骛", description: "累计读完 10 本书，且当前没有任何未读书籍。", icon: "eye.fill", rarity: .gold) { d in
            (d.books.filter { $0.status == .finished }.count >= 10 && d.books.filter { $0.status == .unread }.isEmpty) ? Date() : nil
        },
        BadgeDef(id: 7, title: "极简主义者", description: "书库总数不超过 20 本，但全部为已读状态。", icon: "diamond.fill", rarity: .diamond) { d in
            (d.books.count > 0 && d.books.count <= 20 && d.books.allSatisfy { $0.status == .finished }) ? Date() : nil
        },
        BadgeDef(id: 8, title: "绝对心流", description: "单次阅读记录时长突破 60 分钟。", icon: "water.waves", rarity: .diamond) { d in
            d.records.first(where: { $0.readingDuration >= 3600 })?.date
        },
        BadgeDef(id: 9, title: "不受诱惑", description: "累计读完 20 本书，想读清单依然为空。", icon: "shield.fill", rarity: .obsidian) { d in
            (d.books.filter { $0.status == .finished }.count >= 20 && d.books.filter { $0.isWantToRead }.isEmpty) ? Date() : nil
        },
        BadgeDef(id: 10, title: "破釜沉舟", description: "同一本书产生了至少 7 条阅读轨迹。", icon: "hammer.fill", rarity: .obsidian) { d in
            for book in d.books {
                if (book.readingRecords?.count ?? 0) >= 7 { return book.endTime ?? Date() }
            }
            return nil
        },

        // =======================================
        // 维度二：书山阅海 (11-20)
        // =======================================
        BadgeDef(id: 11, title: "启程之卷", description: "在书库中录入第 1 本书。", icon: "book.closed.fill", rarity: .bronze) { d in
            d.books.compactMap { $0.startTime ?? Date() }.min()
        },
        BadgeDef(id: 12, title: "初窥门径", description: "累计读完 5 本书。", icon: "books.vertical.fill", rarity: .bronze) { d in
            let f = d.books.filter { $0.status == .finished }.compactMap { $0.endTime }.sorted()
            return f.count >= 5 ? f[4] : nil
        },
        BadgeDef(id: 13, title: "破十之志", description: "累计读完 10 本书。", icon: "10.square.fill", rarity: .silver) { d in
            let f = d.books.filter { $0.status == .finished }.compactMap { $0.endTime }.sorted()
            return f.count >= 10 ? f[9] : nil
        },
        BadgeDef(id: 14, title: "书山有路", description: "书库总录入达到 50 本书。", icon: "building.columns.fill", rarity: .silver) { d in
            d.books.count >= 50 ? Date() : nil
        },
        BadgeDef(id: 15, title: "手不释卷", description: "累计读完 50 本书。", icon: "bookmark.fill", rarity: .gold) { d in
            let f = d.books.filter { $0.status == .finished }.compactMap { $0.endTime }.sorted()
            return f.count >= 50 ? f[49] : nil
        },
        BadgeDef(id: 16, title: "百卷通关", description: "累计读完 100 本书。", icon: "rosette", rarity: .gold) { d in
            let f = d.books.filter { $0.status == .finished }.compactMap { $0.endTime }.sorted()
            return f.count >= 100 ? f[99] : nil
        },
        BadgeDef(id: 17, title: "千书之主", description: "书库总录入达到 1000 本书。", icon: "crown.fill", rarity: .diamond) { d in
            d.books.count >= 1000 ? Date() : nil
        },
        BadgeDef(id: 18, title: "学富五车", description: "累计读完 500 本书。", icon: "graduationcap.fill", rarity: .diamond) { d in
            let f = d.books.filter { $0.status == .finished }.compactMap { $0.endTime }.sorted()
            return f.count >= 500 ? f[499] : nil
        },
        BadgeDef(id: 19, title: "光速结案", description: "在 24 小时内添加并读完一本书。", icon: "bolt.fill", rarity: .obsidian) { d in
            d.books.first { book in
                if book.status == .finished, let s = book.startTime, let e = book.endTime {
                    return e.timeIntervalSince(s) <= 86400
                }
                return false
            }?.endTime
        },
        BadgeDef(id: 20, title: "久别重逢", description: "读完一本历时超过 100 天的书。", icon: "arrow.uturn.backward", rarity: .obsidian) { d in
            d.books.first { book in
                if book.status == .finished, let s = book.startTime, let e = book.endTime {
                    return e.timeIntervalSince(s) >= 86400 * 100
                }
                return false
            }?.endTime
        },

        // =======================================
        // 维度三：时光淬炼 (21-30)
        // =======================================
        BadgeDef(id: 21, title: "微光初现", description: "单日阅读达到 15 分钟。", icon: "sun.min.fill", rarity: .bronze) { d in
            d.records.first(where: { $0.readingDuration >= 900 })?.date
        },
        BadgeDef(id: 22, title: "半时之约", description: "单日阅读达到 30 分钟。", icon: "hourglass", rarity: .bronze) { d in
            d.records.first(where: { $0.readingDuration >= 1800 })?.date
        },
        BadgeDef(id: 23, title: "星星之火", description: "累积打卡达到 3 天。", icon: "flame", rarity: .silver) { d in
            let days = Set(d.records.compactMap { $0.date.map { Calendar.current.startOfDay(for: $0) } }).sorted()
            return days.count >= 3 ? days[2] : nil
        },
        BadgeDef(id: 24, title: "渐入佳境", description: "累积打卡达到 7 天。", icon: "flame.fill", rarity: .silver) { d in
            let days = Set(d.records.compactMap { $0.date.map { Calendar.current.startOfDay(for: $0) } }).sorted()
            return days.count >= 7 ? days[6] : nil
        },
        BadgeDef(id: 25, title: "习惯养成", description: "累积打卡达到 21 天。", icon: "calendar.circle.fill", rarity: .gold) { d in
            let days = Set(d.records.compactMap { $0.date.map { Calendar.current.startOfDay(for: $0) } }).sorted()
            return days.count >= 21 ? days[20] : nil
        },
        BadgeDef(id: 26, title: "满月修行", description: "累积打卡达到 30 天。", icon: "moon.fill", rarity: .gold) { d in
            let days = Set(d.records.compactMap { $0.date.map { Calendar.current.startOfDay(for: $0) } }).sorted()
            return days.count >= 30 ? days[29] : nil
        },
        BadgeDef(id: 27, title: "百时历练", description: "累计阅读总时长达到 100 小时。", icon: "clock.badge.checkmark.fill", rarity: .diamond) { d in
            var t = 0.0
            for r in d.records.sorted(by: { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }) {
                t += r.readingDuration / 3600.0
                if t >= 100 { return r.date }
            }
            return nil
        },
        BadgeDef(id: 28, title: "百日筑基", description: "累积打卡达到 100 天。", icon: "building.2.fill", rarity: .diamond) { d in
            let days = Set(d.records.compactMap { $0.date.map { Calendar.current.startOfDay(for: $0) } }).sorted()
            return days.count >= 100 ? days[99] : nil
        },
        BadgeDef(id: 29, title: "千时化境", description: "累计阅读总时长达到 1000 小时。", icon: "infinity.circle.fill", rarity: .obsidian) { d in
            var t = 0.0
            for r in d.records.sorted(by: { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }) {
                t += r.readingDuration / 3600.0
                if t >= 1000 { return r.date }
            }
            return nil
        },
        BadgeDef(id: 30, title: "跨年之约", description: "累积打卡达到 365 天。", icon: "calendar.badge.clock", rarity: .obsidian) { d in
            let days = Set(d.records.compactMap { $0.date.map { Calendar.current.startOfDay(for: $0) } }).sorted()
            return days.count >= 365 ? days[364] : nil
        },

        // =======================================
        // 维度四：思想火花 (31-40)
        // =======================================
        BadgeDef(id: 31, title: "只言片语", description: "记录第 1 条摘录或笔记。", icon: "pencil", rarity: .bronze) { d in
            let dates = (d.excerpts.compactMap{$0.createdAt} + d.notes.compactMap{$0.createdAt}).sorted()
            return dates.first
        },
        BadgeDef(id: 32, title: "金句猎手", description: "累计记录 100 条摘录。", icon: "text.quote", rarity: .bronze) { d in
            let sorted = d.excerpts.compactMap { $0.createdAt }.sorted()
            return sorted.count >= 100 ? sorted[99] : nil
        },
        BadgeDef(id: 33, title: "思想萌芽", description: "写下第 1 条独立思考的笔记。", icon: "lightbulb.fill", rarity: .silver) { d in
            d.notes.compactMap { $0.createdAt }.min()
        },
        BadgeDef(id: 34, title: "摘录狂魔", description: "累计记录 500 条摘录。", icon: "doc.on.doc.fill", rarity: .silver) { d in
            let sorted = d.excerpts.compactMap { $0.createdAt }.sorted()
            return sorted.count >= 500 ? sorted[499] : nil
        },
        BadgeDef(id: 35, title: "下笔有神", description: "累计写下 50 条独立笔记。", icon: "highlighter", rarity: .gold) { d in
            let sorted = d.notes.compactMap { $0.createdAt }.sorted()
            return sorted.count >= 50 ? sorted[49] : nil
        },
        BadgeDef(id: 36, title: "知识万花筒", description: "摘录的来源超过 20 本不同的书。", icon: "camera.filters", rarity: .gold) { d in
            Set(d.excerpts.compactMap { $0.book?.id }).count >= 20 ? Date() : nil
        },
        BadgeDef(id: 37, title: "字字珠玑", description: "单本书的笔记+摘录总数超过 100 条。", icon: "sparkle.magnifyingglass", rarity: .diamond) { d in
            for b in d.books {
                if (b.excerpts?.count ?? 0) + (b.notes?.count ?? 0) >= 100 { return Date() }
            }
            return nil
        },
        BadgeDef(id: 38, title: "字海淘金", description: "总摘录字数超过 100,000 字。", icon: "chart.bar.doc.horizontal", rarity: .diamond) { d in
            var c = 0
            for e in d.excerpts.sorted(by: { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }) {
                c += (e.content?.count ?? 0)
                if c >= 100000 { return e.createdAt }
            }
            return nil
        },
        BadgeDef(id: 39, title: "重度批注", description: "单日本书写超过 20 条摘录或笔记。", icon: "archivebox.fill", rarity: .obsidian) { d in
            var dates: [Date: Int] = [:]
            for e in d.excerpts {
                if let dt = e.createdAt { dates[Calendar.current.startOfDay(for: dt), default: 0] += 1 }
            }
            for n in d.notes {
                if let dt = n.createdAt { dates[Calendar.current.startOfDay(for: dt), default: 0] += 1 }
            }
            if let maxDay = dates.first(where: { $0.value >= 20 }) { return maxDay.key }
            return nil
        },
        BadgeDef(id: 40, title: "思想结晶", description: "独立笔记的总字数超过 20,000 字。", icon: "brain.head.profile", rarity: .obsidian) { d in
            var c = 0
            for n in d.notes.sorted(by: { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }) {
                c += (n.content?.count ?? 0)
                if c >= 20000 { return n.createdAt }
            }
            return nil
        },

        // =======================================
        // 维度五：里程碑 (41-50)
        // =======================================
        BadgeDef(id: 41, title: "满分神作", description: "给一本书打出 5 星评价。", icon: "star.fill", rarity: .bronze) { d in
            d.books.filter { $0.rating == 5 }.compactMap { $0.endTime }.min()
        },
        BadgeDef(id: 42, title: "毒草预警", description: "给一本书打出 1 星评价。", icon: "exclamationmark.triangle.fill", rarity: .bronze) { d in
            d.books.filter { $0.rating == 1 }.compactMap { $0.endTime }.min()
        },
        BadgeDef(id: 43, title: "五彩斑斓", description: "书库中使用了超过 10 种不同的标签。", icon: "tag.fill", rarity: .silver) { d in
            let tags = Set(d.books.flatMap { $0.tags ?? [] })
            return tags.count >= 10 ? Date() : nil
        },
        BadgeDef(id: 44, title: "挑灯夜战", description: "在凌晨 0点 - 4点 产生阅读记录。", icon: "moon.stars.fill", rarity: .silver) { d in
            d.records.first { r in
                guard let dt = r.date else { return false }
                let h = Calendar.current.component(.hour, from: dt)
                return h >= 0 && h < 4
            }?.date
        },
        BadgeDef(id: 45, title: "晨曦行者", description: "在早晨 5点 - 8点 产生阅读记录。", icon: "sunrise.fill", rarity: .gold) { d in
            d.records.first { r in
                guard let dt = r.date else { return false }
                let h = Calendar.current.component(.hour, from: dt)
                return h >= 5 && h < 8
            }?.date
        },
        BadgeDef(id: 46, title: "周末狂人", description: "单日阅读时长达到 5 小时。", icon: "tent.fill", rarity: .gold) { d in
            d.records.first(where: { $0.readingDuration >= 18000 })?.date
        },
        BadgeDef(id: 47, title: "马拉松", description: "单日阅读总时长突破 180 分钟。", icon: "figure.run", rarity: .diamond) { d in
            d.records.first(where: { $0.readingDuration >= 10800 })?.date
        },
        BadgeDef(id: 48, title: "年度收官", description: "在 12 月 31 日完成一本书的阅读。", icon: "gift.fill", rarity: .diamond) { d in
            d.books.first { b in
                guard let e = b.endTime else { return false }
                let cal = Calendar.current
                return cal.component(.month, from: e) == 12 && cal.component(.day, from: e) == 31
            }?.endTime
        },
        BadgeDef(id: 49, title: "时间黑洞", description: "单本书的阅读总时长超过 100 小时。", icon: "hurricane", rarity: .obsidian) { d in
            for book in d.books {
                let t = (book.readingRecords ?? []).reduce(0) { $0 + $1.readingDuration }
                if t >= 360000 { return book.endTime ?? Date() }
            }
            return nil
        },
        BadgeDef(id: 50, title: "极光缔造者", description: "大满贯：解锁前面全部 49 个徽章。", icon: "sparkles", rarity: .obsidian) { d in
            return nil
        }
    ]
    
    /// 执行一次全盘推导，根据当期用户数据包解锁相应徽章并写入时间戳。
    func evaluate(books: [Book], records: [ReadingRecord], excerpts: [Excerpt], notes: [Note]) -> [Int: Date] {
        let package = AchievementData(books: books, records: records, excerpts: excerpts, notes: notes)
        var unlocked: [Int: Date] = [:]
        for badge in allBadges { if let date = badge.conditionCheck(package) { unlocked[badge.id] = date } }
        if unlocked.count >= 49 && !unlocked.keys.contains(50) { unlocked[50] = Date() }
        return unlocked
    }
}

// MARK: - 殿堂级陈列室 UI

/// 游戏化荣誉勋章展示墙 (Achievement Wall)。
///
/// 该页面将在初始化时调用底层 `AchievementEngine` 扫描并演算出全局 50 种徽章的解锁状态。
/// 配合高度优化的自适应瀑布流网格，以及基于物理翻转的卡牌动画，打造极具成就感的数据汇总展柜。
struct AchievementWallView: View {
    @Query var allBooks: [Book]
    @Query var allRecords: [ReadingRecord]
    @Query var allExcerpts: [Excerpt]
    @Query var allNotes: [Note]
    
    @State private var unlockedBadges: [Int: Date] = [:]
    let dimensions = ["极简约束", "书山阅海", "时光淬炼", "思想火花", "里程碑"]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("阅历陈列室")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                    Text("共 \(unlockedBadges.count) / 50 项荣誉已解锁")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 50)
                .padding(.bottom, 40)
                
                // ✨ 使用单一 LazyVGrid 配合 Section，彻底解决滚动高度计算导致的位置乱跳
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 20)], spacing: 24) {
                    ForEach(0..<5, id: \.self) { sectionIndex in
                        let sectionBadges = AchievementEngine.shared.allBadges.filter { $0.id > sectionIndex * 10 && $0.id <= (sectionIndex + 1) * 10 }
                        
                        Section(header: sectionHeader(title: dimensions[sectionIndex])) {
                            ForEach(sectionBadges) { badge in
                                MasterpieceBadgeView(
                                    badge: badge,
                                    isUnlocked: unlockedBadges.keys.contains(badge.id),
                                    unlockDate: unlockedBadges[badge.id]
                                )
                                // ✨ 为每个视图提供稳定的 ID 标识，防止复用混乱
                                .id("badge_\(badge.id)")
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 80)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            unlockedBadges = AchievementEngine.shared.evaluate(books: allBooks, records: allRecords, excerpts: allExcerpts, notes: allNotes)
        }
    }
    
    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary.opacity(0.8))
            Spacer()
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - 高定金属卡片组件

/// 支持 3D 翻转的独立成就徽章渲染容器。
///
/// **渲染特性：**
/// 使用绝对刚性尺寸（宽 100，高 140），杜绝了内部状态切换导致重绘时所引发的瀑布流乱跳问题。
/// 支持未解锁时的暗金占位效果，以及解锁后通过 `RadialGradient` 构建的高性能材质光效反射。
struct MasterpieceBadgeView: View {
    let badge: BadgeDef
    let isUnlocked: Bool
    let unlockDate: Date?
    
    @State private var isFlipped = false
    @State private var isHovered = false
    
    var body: some View {
        // ✨ 绝对刚性容器。提供一个死死固定为 100x140 的外部框架。
        // 将所有的形变、旋转特效限制在 overlay 内部，彻底切断形变对 LazyVGrid 的影响。
        Color.clear
            .frame(width: 100, height: 140)
            .contentShape(Rectangle()) // 保证透明区域也能接收点击和悬停
            .overlay(
                ZStack {
                    backSide
                        .opacity(isFlipped ? 1 : 0)
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    frontSide
                        .opacity(isFlipped ? 0 : 1)
                }
                .frame(width: 100, height: 140)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .offset(y: isHovered ? -4 : 0)
            )
            .onHover { h in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isHovered = h }
                if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { isFlipped.toggle() }
            }
    }
    
    // 正面
    private var frontSide: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isUnlocked ?
                    LinearGradient(colors: badge.rarity.baseColors, startPoint: .topLeading, endPoint: .bottomTrailing) :
                    LinearGradient(colors: [Color.secondary.opacity(0.1), Color.secondary.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                )
            
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(isUnlocked ? 0.15 : 0.05)).padding(5)
            
            VStack(spacing: 10) {
                Spacer()
                ZStack {
                    if isUnlocked && (badge.rarity == .obsidian || badge.rarity == .diamond) {
                        // ✨ 用 RadialGradient 替代极度耗费性能的 .blur(radius: 8)
                        Circle()
                            .fill(RadialGradient(colors: [Color.white.opacity(0.4), .clear], center: .center, startRadius: 0, endRadius: 25))
                            .frame(width: 50, height: 50)
                    }
                    Image(systemName: badge.icon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(isUnlocked ? badge.rarity.textColor : .secondary.opacity(0.3))
                        .shadow(color: Color.black.opacity(0.3), radius: 3, y: 2)
                }
                VStack(spacing: 3) {
                    Text(badge.title)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(isUnlocked ? badge.rarity.textColor : .secondary.opacity(0.5))
                        .lineLimit(1)
                    Text(badge.rarity.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isUnlocked ? badge.rarity.textColor.opacity(0.7) : .clear)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.black.opacity(0.2)).clipShape(Capsule())
                }
                Spacer()
            }
            
            if isUnlocked {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(stops: [.init(color: .white.opacity(0.4), location: isHovered ? 0.0 : -0.2), .init(color: .clear, location: isHovered ? 0.6 : 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .animation(.easeInOut(duration: 0.8), value: isHovered)
            }
            RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isUnlocked ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 1)
        }
        // ✨ 将阴影挂载在纯净的形状上，进一步优化离屏渲染
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .shadow(color: isUnlocked ? badge.rarity.baseColors[0].opacity(isHovered ? 0.6 : 0.3) : .clear, radius: isHovered ? 12 : 6, y: isHovered ? 6 : 3)
        )
    }
    
    // 背面
    private var backSide: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(nsColor: .controlBackgroundColor).opacity(0.95))
            
            VStack(spacing: 8) {
                Image(systemName: isUnlocked ? "seal.fill" : "lock.fill")
                    .font(.system(size: 18))
                    .foregroundColor(isUnlocked ? badge.rarity.baseColors[0] : .secondary.opacity(0.5))
                
                Text(badge.title)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(isUnlocked ? .primary : .secondary)
                
                Text(badge.description)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 8)
                
                Divider().frame(width: 40)
                
                VStack(spacing: 2) {
                    Text(isUnlocked ? "达成于" : "尚未解锁")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    if isUnlocked, let date = unlockDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
            }
            RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isUnlocked ? badge.rarity.baseColors[0].opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 2)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
        )
    }
}
#endif
