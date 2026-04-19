import SwiftData
import SwiftUI

#if os(iOS)
struct MobileBookDetailView: View {
    let book: Book
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showDeleteAlert = false
    @State private var showAddExcerptSheet = false
    @State private var showEditSheet = false
    @State private var showMaxWantToReadAlert = false
    
    @State private var isDeleteMode = false
    @Namespace private var animationNamespace
    
    var body: some View {
        let safeTitle = book.title ?? "未知书名"
        let safeAuthor = book.author ?? "未知作者"
        let safeStatus = book.status ?? .unread
        
        ZStack {
            // ================= 1. 全局无界内容区 =================
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 32) {
                    
                    // ================= 👆 上半部分：书籍详情大模块 =================
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // --- 上：左右分栏 (左封面，右信息) ---
                        HStack(alignment: .top, spacing: 16) {
                            // 左侧：封面
                            LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                                .frame(width: 120, height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: Color.black.opacity(0.15), radius: 12, y: 6) // 🍏 系统原生轻阴影
                            
                            // 右侧：紧凑型档案信息
                            VStack(alignment: .leading, spacing: 0) {
                                // 书名、作者与想读按钮
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .top) {
                                        Text(safeTitle)
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                        Spacer(minLength: 4)
                                        if safeStatus == .unread {
                                            MobileWantToReadToggle(book: book, showMaxAlert: $showMaxWantToReadAlert)
                                                .offset(y: -4)
                                        }
                                    }
                                    Text(safeAuthor)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer() // 弹性撑开
                                
                                // 状态切换器
                                MobileCompactStatusPicker(book: book, animationNamespace: animationNamespace)
                                
                                Spacer() // 弹性撑开
                                
                                // 阅读日期与历时
                                MobileCompactDatePickers(book: book)
                                
                                Spacer() // 弹性撑开
                                
                                // 个人评价
                                MobileCompactRatingView(book: book)
                            }
                            .frame(height: 180)
                        }
                        
                        Divider()
                        // --- 下：多列自适应标签组件 ---
                        MobileCompactTagsView(book: book)
                    }
                    .padding(20)
                    .background(Color(uiColor: .secondarySystemGroupedBackground)) // 🍏 原生卡片色
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    
                    // ================= 👇 下半部分：摘录与笔记展示区 =================
                    VStack(spacing: 20) {
                        // 区域头部栏
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("思考的痕迹")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("留住阅读时的金句与灵感")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isDeleteMode.toggle() }
                                }) {
                                    Text(isDeleteMode ? "完成" : "管理")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(isDeleteMode ? .white : .primary)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(isDeleteMode ? Color.red : Color.secondary.opacity(0.1)) // 原生红底 / 灰底
                                        .clipShape(Capsule())
                                }
                                
                                Button(action: { showAddExcerptSheet = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "quote.opening").font(.system(size: 10))
                                        Text("记摘录").font(.system(size: 12, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(Color.indigo) // 🍏 系统原生靛蓝色
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // 混合时间线列表渲染
                        MobileExcerptsAndNotesList(book: book, isDeleteMode: isDeleteMode) { itemToDelete in
                            deleteRecord(itemToDelete)
                        }
                    }
                }
                .padding(.bottom, 80)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground)) // 🍏 全局系统灰底
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showEditSheet = true }) { Label("编辑书籍", systemImage: "pencil") }
                    Button(role: .destructive, action: { showDeleteAlert = true }) { Label("删除书籍", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
        }
        .alert("删除书籍", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("确认删除", role: .destructive) {
                modelContext.delete(book)
                dismiss()
            }
        } message: { Text("确定要删除《\(safeTitle)》吗？相关的读书笔记也会一并清除。") }
        .alert("席位已满", isPresented: $showMaxWantToReadAlert) {
            Button("知道啦", role: .cancel) {}
        } message: { Text("主页“想读焦点”最多同时放置 4 本书。请先取消其他的想读状态吧！") }
        .sheet(isPresented: $showAddExcerptSheet) { MobileAddExcerptSheet(book: book) }
        .sheet(isPresented: $showEditSheet) { MobileBookEditorSheet(book: book) }
    }
    
    private func deleteRecord(_ item: MobileRecordItem) {
        withAnimation(.spring()) {
            switch item {
            case .excerpt(let excerpt): modelContext.delete(excerpt)
            case .note(let note): modelContext.delete(note)
            }
        }
        let excerptCount = book.excerpts?.count ?? 0
        let noteCount = book.notes?.count ?? 0
        if (excerptCount + noteCount) <= 1 {
            withAnimation { isDeleteMode = false }
        }
    }
}

// MARK: - 🧩 右侧超紧凑组件：想读标记按钮
private struct MobileWantToReadToggle: View {
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
private struct MobileCompactStatusPicker: View {
    @Bindable var book: Book
    var animationNamespace: Namespace.ID
    @Environment(\.modelContext) private var modelContext
    
    // ✨ 核心修复：使用真实的 BookStatus 枚举，而不是字符串
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
    
    private func autoGenerateReadingRecord(for book: Book, duration: TimeInterval) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        
        do {
            // ✨ 核心修复：不依赖未知的 reading_record 关系属性，直接安全查询物理打卡记录
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
private struct MobileCompactDatePickers: View {
    @Bindable var book: Book
    var body: some View {
        HStack(spacing: 8) {
            VStack(spacing: 6) {
                CompactDateBtn(icon: "play.fill", title: "开始", date: $book.startTime)
                // ✨ 核心修复：比对正确的枚举 .finished
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

private struct CompactDateBtn: View {
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
private struct MobileCompactRatingView: View {
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
private struct MobileCompactTagsView: View {
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

// MARK: - 🧩 混合列表渲染引擎 (全面拥抱原生 Markdown)
private struct MobileExcerptsAndNotesList: View {
    let book: Book
    let isDeleteMode: Bool
    let onDelete: (MobileRecordItem) -> Void
    
    private var mixedRecords: [MobileRecordItem] {
        let excerpts = (book.excerpts ?? []).map { MobileRecordItem.excerpt($0) }
        let notes = (book.notes ?? []).map { MobileRecordItem.note($0) }
        return (excerpts + notes).sorted { $0.date > $1.date }
    }
    
    var body: some View {
        if mixedRecords.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "leaf").font(.system(size: 32)).foregroundColor(Color.gray.opacity(0.5))
                Text("暂无记录，写下你的感悟吧").font(.system(size: 14)).foregroundColor(.secondary)
            }
            .padding(.vertical, 60)
        } else {
            LazyVStack(spacing: 16) {
                ForEach(mixedRecords) { item in
                    MobileRecordCardWrapper(item: item, isDeleteMode: isDeleteMode) { onDelete(item) }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - 📱 卡片包装器
private struct MobileRecordCardWrapper: View {
    let item: MobileRecordItem
    let isDeleteMode: Bool
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch item {
                case .excerpt(let excerpt): MobileExcerptCard(excerpt: excerpt)
                case .note(let note): MobileNoteCard(note: note)
                }
            }
            
            if isDeleteMode {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.red)
                        .clipShape(Circle())
                        .shadow(color: Color.red.opacity(0.4), radius: 6, y: 3)
                }
                .offset(x: 8, y: -8)
                .transition(.scale.combined(with: .opacity))
                .zIndex(1)
            }
        }
    }
}

// MARK: - 摘录与笔记卡片 (原生 Markdown 解析版)
private struct MobileExcerptCard: View {
    let excerpt: Excerpt
    var body: some View {
        let safeContent = excerpt.content ?? ""
        let safeDate = excerpt.createdAt ?? Date()
        
        VStack(alignment: .leading, spacing: 12) {
            // 🍏 LocalizedStringKey 魔法，自动解析粗体、斜体！
            Text(LocalizedStringKey(safeContent))
                .font(.system(size: 15, weight: .regular, design: .serif))
                .lineSpacing(6)
                .foregroundColor(.primary)
            HStack {
                Spacer()
                Text(safeDate, format: .dateTime.year().month().day())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.gray.opacity(0.5))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MobileNoteCard: View {
    let note: Note
    var body: some View {
        let safeContent = note.content ?? ""
        let safeDate = note.createdAt ?? Date()
        
        VStack(alignment: .leading, spacing: 12) {
            // 🍏 SwiftUI 底层直接处理，支持各级标题 (Header) 与列表
            Text(LocalizedStringKey(safeContent))
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundColor(.primary)
            HStack {
                Spacer()
                Text(safeDate, format: .dateTime.year().month().day())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.gray.opacity(0.5))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.05)) // 笔记用极淡的暖黄色区分
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// 全局支持模型
enum MobileRecordItem: Identifiable {
    case excerpt(Excerpt)
    case note(Note)
    var id: String {
        switch self {
        case .excerpt(let e): return "excerpt-\(e.id ?? UUID().uuidString)"
        case .note(let n): return "note-\(n.id ?? UUID().uuidString)"
        }
    }
    var date: Date {
        switch self {
        case .excerpt(let e): return e.createdAt ?? Date.distantPast
        case .note(let n): return n.createdAt ?? Date.distantPast
        }
    }
}
#endif
