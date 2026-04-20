#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 🧩 右侧超紧凑组件：想读标记按钮

/// 仅在“待读”状态下出现的星标焦点收藏按钮。
/// 会通过查询底层 SwiftData，严格拦截超过 4 本想读书籍的录入请求。
struct MobileWantToReadToggle: View {
    @Bindable var book: Book
    @Binding var showMaxAlert: Bool
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Button {
            handleToggle()
        } label: {
            let isWant = book.isWantToRead
            Image(systemName: isWant ? "bookmark.fill" : "bookmark")
                .font(.system(size: 16))
                .foregroundColor(isWant ? .orange : Color.gray.opacity(0.5))
                .padding(4)
        }
        .buttonStyle(.plain)
    }
    
    private func handleToggle() {
        let isWant = book.isWantToRead
        if isWant {
            withAnimation(.spring()) { book.isWantToRead = false }
        } else {
            do {
                let descriptor = FetchDescriptor<Book>(predicate: #Predicate<Book> { $0.isWantToRead == true })
                let count = try modelContext.fetchCount(descriptor)
                if count >= 4 {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    showMaxAlert = true
                } else {
                    withAnimation(.spring()) { book.isWantToRead = true }
                }
            } catch { print("想读状态查询失败: \(error)") }
        }
    }
}

// MARK: - 🧩 右侧超紧凑组件：状态选择器 (含自动打卡)

/// 紧凑的三段式状态拨片器。
///
/// 核心联动逻辑：
/// - 切换为 `reading`（在读）或 `finished`（已读）时，自动赋予当前时刻为开始/结束时间。
/// - 并且会自动探针当天的打卡记录表：如果发现没有打卡流水，会无感插入一条底薪时长的 `ReadingRecord` 以保证时间轴曲线不中断。
struct MobileCompactStatusPicker: View {
    @Bindable var book: Book
    var animationNamespace: Namespace.ID
    @Environment(\.modelContext) private var modelContext
    
    let options: [(BookStatus, String)] = [(.unread, "待读"), (.reading, "在读"), (.finished, "已读完")]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { opt in
                let safeStatus = book.status ?? .unread
                let isSelected = safeStatus == opt.0
                Button(action: {
                    handleStatusChange(to: opt.0)
                }) {
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.blue)
                                .matchedGeometryEffect(id: "mobile-status-bg", in: animationNamespace)
                        }
                        Text(opt.1)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .white : .secondary)
                    }
                    .frame(height: 24)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private func handleStatusChange(to newStatus: BookStatus) {
        let safeStatus = book.status ?? .unread
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            let oldStatus = safeStatus
            book.status = newStatus
            let now = Date()
            
            if newStatus == .reading {
                if book.startTime == nil { book.startTime = now }
                if oldStatus == .unread { autoGenerateReadingRecord(for: book, duration: 1) }
            } else if newStatus == .finished {
                if book.startTime == nil { book.startTime = now }
                if book.endTime == nil { book.endTime = now }
                book.progress = 100
                autoGenerateReadingRecord(for: book, duration: 10)
            } else if newStatus == .unread {
                book.progress = 0
                book.startTime = nil
                book.endTime = nil
            }
        }
    }
    
    /// 当变更阅读状态时，系统静默补偿一条当天的低保阅读流水。
    private func autoGenerateReadingRecord(for book: Book, duration: TimeInterval) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        
        do {
            let allRecords = try modelContext.fetch(FetchDescriptor<ReadingRecord>())
            let hasRecordToday = allRecords.contains { calendar.isDate($0.date ?? Date.distantPast, inSameDayAs: todayStart) }
            
            if !hasRecordToday {
                let newRecord = ReadingRecord(date: Date(), readingDuration: duration)
                modelContext.insert(newRecord)
                try? modelContext.save()
            }
        } catch {}
    }
}

// MARK: - 🧩 右侧超紧凑组件：双列日期与历时区块

/// 并排渲染的开始与结束时间选取器，旁边辅以大型的历时天数统计方块。
struct MobileCompactDatePickers: View {
    @Bindable var book: Book
    var body: some View {
        HStack(spacing: 8) {
            VStack(spacing: 6) {
                CompactDateBtn(icon: "play.fill", title: "开始", date: $book.startTime)
                CompactDateBtn(icon: "flag.fill", title: "结束", date: $book.endTime, isDisabled: book.status != .finished)
            }
            
            if book.status == .finished, let start = book.startTime, let end = book.endTime {
                let days = max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1)
                VStack(spacing: 2) {
                    Text("\(days)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.mint)
                    Text("历时(天)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .frame(width: 56, height: 54)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

/// 承接外层传递的 Binding 时间绑定，支持点击唤起原生 iOS DatePicker (Popover 气泡风格)。
struct CompactDateBtn: View {
    let icon: String; let title: String; @Binding var date: Date?; var isDisabled: Bool = false
    @State private var showPicker = false
    
    var body: some View {
        Button(action: { showPicker = true }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(date != nil ? .blue : Color.gray.opacity(0.5))
                
                if let d = date {
                    Text(d.formatted(date: .numeric, time: .omitted))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                } else {
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(Color.secondary.opacity(0.1)) // 极度扁平轻量的背景
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1.0)
        .popover(isPresented: $showPicker) {
            DatePicker("", selection: Binding(get: { date ?? Date() }, set: { date = $0 }), displayedComponents: .date)
                .datePickerStyle(.graphical).padding()
        }
    }
}

// MARK: - 🧩 右侧超紧凑组件：小星级与评价文字

/// 单排打分控件组件。
/// 提供五颗支持轻度物理触控反馈的点击星标。满分 5 星自动解锁高亮皇冠标志。
struct MobileCompactRatingView: View {
    @Bindable var book: Book
    let ratingTexts = ["", "一星毒草", "二星平庸", "三星粮草", "四星推荐", "改变人生"]
    
    var body: some View {
        let safeRating = book.rating ?? 0
        HStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(1 ... 5, id: \.self) { star in
                    let isFilled = safeRating >= star
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(isFilled ? .yellow : Color.secondary.opacity(0.2))
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3)) { book.rating = star }
                        }
                }
            }
            Spacer()
            if safeRating > 0 {
                Text(safeRating < ratingTexts.count ? ratingTexts[safeRating] : "")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
                if safeRating == 5 { Image(systemName: "crown.fill").font(.system(size: 10)).foregroundColor(.orange) }
            } else {
                Text("暂无评价").font(.system(size: 10, weight: .medium)).foregroundColor(Color.gray.opacity(0.5))
            }
        }
    }
}

// MARK: - 🧩 底部超紧凑组件：自适应多行标签网格

/// 紧贴在书籍元数据下方的自适应换行标签墙。
/// 最多支持高亮选中 3 个标签作为本数的索引特征。
struct MobileCompactTagsView: View {
    @Bindable var book: Book
    let predefinedTags = ["哲学", "历史", "商业", "科技", "文学", "成长", "设计", "心理", "传记", "管理"]
    
    var body: some View {
        let safeTags = book.tags ?? []
        let columns = [GridItem(.adaptive(minimum: 54, maximum: 70), spacing: 8)]
        
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(predefinedTags, id: \.self) { tag in
                let isSelected = safeTags.contains(tag)
                let isMaxed = safeTags.count >= 3 && !isSelected
                
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        if isSelected { book.tags?.removeAll(where: { $0 == tag }) }
                        else if safeTags.count < 3 {
                            if book.tags == nil { book.tags = [] }
                            book.tags?.append(tag)
                        }
                    }
                }) {
                    Text(tag)
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(isSelected ? Color.indigo : Color.secondary.opacity(0.1)) // 🍏 苹果靛蓝
                        .clipShape(Capsule())
                }
                .disabled(isMaxed)
                .opacity(isMaxed ? 0.4 : 1.0)
            }
        }
    }
}
#endif
