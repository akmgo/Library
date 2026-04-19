#if os(macOS)
import SwiftUI
import SwiftData
import AppKit

// MARK: - 1. 主详情页容器 (BookDetailView)
struct BookDetailView: View {
    let book: Book
    let namespace: Namespace.ID
    @Binding var activeCoverID: String
    @Binding var selectedBook: Book?
    
    @Environment(\.modelContext) private var modelContext
    
    // ✨ 弹窗控制状态
    @State private var showAddExcerptSheet = false
    @State private var showAddNoteSheet = false
    @State private var isDeleteMode = false
    
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        ZStack {
            // ================= 1. 纯净毛玻璃背景 =================
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()
            
            // 细微的系统遮罩层，增加立体感 (替代手动的 isDark 判断)
            Color(nsColor: .windowBackgroundColor).opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // 点击空白处返回，享受右滑出退场动画
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { selectedBook = nil }
                }
            
            // ================= 2. 全局无界内容区 =================
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 80) {
                    // 👆 上大模块：重构后的优雅书籍看板
                    BookDossierView(book: book)
                        .zIndex(1)
                                                                                                        
                    // 👇 下大模块：摘要和笔记
                    VStack(spacing: 30) {
                        // 标题与控制按钮
                        VStack(spacing: 16) {
                            HStack(alignment: .center) {
                                Text("思考的痕迹")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                HStack(spacing: 12) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isDeleteMode.toggle() }
                                    }) {
                                        Label(isDeleteMode ? "完成" : "管理", systemImage: isDeleteMode ? "checkmark" : "trash")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(isDeleteMode ? .blue : .gray)
                                    .controlSize(.large)
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showAddNoteSheet = true }
                                    }) {
                                        Label("笔记", systemImage: "square.and.pencil")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.purple)
                                    .controlSize(.large)
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showAddExcerptSheet = true }
                                    }) {
                                        Label("摘录", systemImage: "quote.opening")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.indigo)
                                    .controlSize(.large)
                                }
                            }
                            Divider()
                        }
                            
                        BookExcerptsView(
                            book: book,
                            isDeleteMode: isDeleteMode,
                            onDelete: { itemToDelete in deleteRecord(itemToDelete) }
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 100)
                .padding(.top, 100)
            }
            .ignoresSafeArea(edges: .top)
            
            // ================= 3. 弹窗引擎池 =================
            .sheet(isPresented: $showAddExcerptSheet) {
                AddContentSheet(isPresented: $showAddExcerptSheet, book: book, mode: .excerpt)
            }
            .sheet(isPresented: $showAddNoteSheet) {
                AddContentSheet(isPresented: $showAddNoteSheet, book: book, mode: .note)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showEditSheet = true } }) {
                    Image(systemName: "pencil")
                }
                .help("编辑书籍信息")
                
                Button(action: { showDeleteAlert = true }) {
                    Image(systemName: "trash").foregroundStyle(Color.red)
                }
                .help("彻底删除书籍")
            }
        }
        .sheet(isPresented: $showEditSheet) { BookEditorSheet(isPresented: $showEditSheet, bookToEdit: book) }
        .alert("删除书籍", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("确认删除", role: .destructive) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { selectedBook = nil }
                // 延迟一点执行删除，让返回动画播完
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { modelContext.delete(book) }
            }
        } message: {
            Text("确定要删除《\(book.title ?? "未知")》吗？相关的读书笔记也会一并清除。")
        }
    }
    
    private func deleteRecord(_ item: RecordItem) {
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

// MARK: - 2. 核心信息档案板 (BookDossierView)
private struct BookDossierView: View {
    @Bindable var book: Book
    @Namespace private var animationNamespace
    @State private var showMaxWantToReadAlert = false
    
    var body: some View {
        let safeTitle = book.title ?? "未知书名"
        let safeAuthor = book.author ?? "未知作者"
        
        VStack(alignment: .leading, spacing: 32) {
            // ================= 👆 上半部分：左右分栏 =================
            HStack(alignment: .top, spacing: 40) {
                
                // 👈 左侧：高清大封面
                LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                    .frame(width: 300, height: 450)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                
                // 👉 右侧：书名与交互台
                VStack(alignment: .leading, spacing: 0) {
                    
                    // 1. 书名与作者
                    HStack(alignment: .top) {
                        HStack(alignment: .center, spacing: 16) {
                            Text(safeTitle)
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            if book.status == .unread {
                                WantToReadToggle(book: book, showMaxAlert: $showMaxWantToReadAlert)
                                    .offset(y: -4)
                            }
                        }
                        
                        Spacer(minLength: 20)
                        
                        Text(safeAuthor)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(2)
                            .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    // 2. 依次垂直紧凑堆叠组件
                    VStack(alignment: .leading, spacing: 20) {
                        BookStatusPicker(book: book, animationNamespace: animationNamespace)
                        BookDatePickers(book: book)
                        BookRatingView(book: book)
                    }
                }
                .frame(height: 450)
                .frame(maxWidth: .infinity)
            }
            
            // ================= 👇 下半部分：标签模块 =================
            BookTagsView(book: book)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
        .alert("席位已满", isPresented: $showMaxWantToReadAlert) {
            Button("知道啦", role: .cancel) {}
        } message: {
            Text("你的主页“想读焦点”最多只能同时放置 2 本书。请先取消其他的想读状态，把位置腾出来吧！")
        }
    }
}

// MARK: - 3. 状态选择器 (BookStatusPicker)
private struct BookStatusPicker: View {
    @Bindable var book: Book
    var animationNamespace: Namespace.ID
    
    @Environment(\.modelContext) private var modelContext
    let statusOptions: [(BookStatus, String)] = [(.unread, "待读"), (.reading, "在读"), (.finished, "已读")]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("当前状态", systemImage: "book.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.blue)
            
            HStack(spacing: 0) {
                ForEach(statusOptions, id: \.0) { opt in
                    let isSelected = (book.status ?? .unread) == opt.0
                    Button(action: {
                        handleStatusChange(to: opt.0)
                    }) {
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.blue)
                                    .matchedGeometryEffect(id: "status-bg", in: animationNamespace)
                            }
                            Text(opt.1)
                                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : .primary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }.frame(height: 36)
                    }
                    .buttonStyle(.plain)
                    .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                }
            }
            .padding(4)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
        }
    }
    
    private func handleStatusChange(to newStatus: BookStatus) {
        let oldStatus = book.status ?? .unread
        let wasFinished = (oldStatus == .finished)
        let willFinish = (newStatus == .finished)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            book.status = newStatus
            
            let now = Date()
            if newStatus == .reading {
                if book.startTime == nil { book.startTime = now }
            } else if newStatus == .finished {
                if book.startTime == nil { book.startTime = now }
                if book.endTime == nil { book.endTime = now }
            }
        }
        
        if willFinish && !wasFinished {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .triggerConfetti, object: nil)
            }
        }
    }
}

// MARK: - 4. 日期选择组件 (BookDatePickers)
private struct BookDatePickers: View {
    @Bindable var book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("阅读旅程", systemImage: "calendar")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.mint)
            
            HStack(spacing: 16) {
                if book.status == .unread {
                    Text("等待翻开第一页...")
                        .font(.system(size: 14, weight: .medium, design: .serif)).italic()
                        .foregroundColor(.secondary)
                        .frame(minHeight: 36)
                    Spacer()
                } else {
                    AdvancedDatePickerButton(icon: "play.fill", title: "开始", date: $book.startTime)
                    AdvancedDatePickerButton(icon: "flag.fill", title: "结束", date: $book.endTime, isDisabled: book.status != .finished)
                    
                    if book.status == .finished, let start = book.startTime, let end = book.endTime {
                        let diff = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start), to: Calendar.current.startOfDay(for: end)).day ?? 0
                        let days = max(1, diff + 1)
                        
                        HStack {
                            Text("历时").font(.system(size: 14, weight: .bold)).foregroundColor(.secondary)
                            Spacer()
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(days)").font(.system(size: 18, weight: .black, design: .rounded)).foregroundColor(.mint)
                                Text("天").font(.system(size: 12, weight: .bold)).foregroundColor(.mint)
                            }
                        }
                        .frame(width: 90).padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
                        .transition(.scale.combined(with: .opacity))
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
        }
    }
}

private struct AdvancedDatePickerButton: View {
    let icon: String; let title: String; @Binding var date: Date?; var isDisabled: Bool = false
    @State private var isShowingPopover = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isShowingPopover.toggle() }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(date != nil ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1)).frame(width: 36, height: 36)
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(date != nil ? .blue : .secondary)
                }
                
                HStack(spacing: 10) {
                    Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                    if let d = date {
                        Text(d.formatted(date: .numeric, time: .omitted)).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.primary)
                    } else {
                        Text("尚未设置").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.secondary.opacity(0.6))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity)
            .background(isHovered ? Color.secondary.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain).disabled(isDisabled).opacity(isDisabled ? 0.4 : 1.0)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.2)) { isHovered = h }
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .popover(isPresented: $isShowingPopover, arrowEdge: Edge.bottom) {
            ScreenshotStyleDatePicker(selectedDate: $date)
        }
    }
}

private struct ScreenshotStyleDatePicker: View {
    @Binding var selectedDate: Date?
    var customCalendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Spacer()
                Capsule().fill(Color.blue).frame(width: 3, height: 14)
                Text("时间").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary)
                Spacer()
            }.padding(.top, 16).padding(.bottom, 4)
            
            QuickOptionRow(icon: "star.fill", iconColor: .yellow, title: "今天", isSelected: isToday(selectedDate)) { selectedDate = Date() }
            Divider().padding(.vertical, 8).padding(.horizontal, 16)
            
            DatePicker("", selection: Binding(get: { selectedDate ?? Date() }, set: { selectedDate = $0 }), displayedComponents: .date)
                .datePickerStyle(.graphical).labelsHidden()
                .environment(\.calendar, customCalendar)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .scaleEffect(1.5)
                .frame(width: 250, height: 260).padding(.horizontal, 24).padding(.bottom, 20)
        }
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func isToday(_ date: Date?) -> Bool {
        guard let date = date else { return false }
        return Calendar.current.isDateInToday(date)
    }
}

private struct QuickOptionRow: View {
    let icon: String; let iconColor: Color; let title: String; let isSelected: Bool; let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(iconColor).frame(width: 20)
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                if isSelected { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundColor(.blue) }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(isHovered ? Color.secondary.opacity(0.1) : Color.clear).cornerRadius(8).padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 5. 评分组件 (BookRatingView)
private struct BookRatingView: View {
    @Bindable var book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("个人评分", systemImage: "star.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.yellow)
            
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { index in
                    let currentRating = book.rating ?? 0
                    Image(systemName: currentRating >= index ? "star.fill" : "star")
                        .font(.system(size: 24))
                        .foregroundColor(currentRating >= index ? .yellow : .secondary.opacity(0.3))
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if currentRating == index {
                                    book.rating = 0
                                } else {
                                    book.rating = index
                                }
                            }
                        }
                        .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
        }
    }
}

// MARK: - 6. 标签管理 (BookTagsView)
private struct BookTagsView: View {
    @Bindable var book: Book
    let predefinedTags: [String] = ["哲学", "历史", "人文", "经典", "社会", "政治", "经济", "法律", "心理", "思考", "成长", "管理", "商业", "投资", "技术", "文学", "传记", "艺术", "宗教", "科普", "编程", "玄幻"]
    
    var body: some View {
        let safeTags: [String] = book.tags ?? []
        
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("知识标签库", systemImage: "tag.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.purple)
                Spacer()
                Text("\(safeTags.count) / 3").font(.system(size: 14, weight: .bold)).foregroundColor(.secondary)
            }
            
            let columns = [GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 12)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(predefinedTags, id: \.self) { tag in
                    let isSelected = safeTags.contains(tag)
                    let isMaxed = safeTags.count >= 3 && !isSelected
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            var currentTags = book.tags ?? []
                            if isSelected {
                                currentTags.removeAll(where: { $0 == tag })
                            } else if currentTags.count < 3 {
                                currentTags.append(tag)
                            }
                            book.tags = currentTags
                        }
                    }) {
                        Text(tag).font(.system(size: 14, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .white : (isMaxed ? .secondary.opacity(0.6) : .primary))
                            .frame(height: 36).frame(maxWidth: .infinity)
                            .background(isSelected ? Color.purple : (isMaxed ? Color.secondary.opacity(0.05) : Color(nsColor: .controlBackgroundColor)))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isSelected ? Color.purple : Color.secondary.opacity(0.1), lineWidth: 1))
                            .scaleEffect(isSelected ? 1.05 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .disabled(isMaxed)
                    .onHover { h in if h && !isMaxed { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                }
            }
        }
    }
}

// MARK: - 7. 想读焦点开关 (WantToReadToggle)
private struct WantToReadToggle: View {
    @Bindable var book: Book
    @Binding var showMaxAlert: Bool
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Button(action: handleToggle) {
            Image(systemName: book.isWantToRead ? "bookmark.fill" : "bookmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(book.isWantToRead ? .orange : .secondary)
                .frame(width: 36, height: 36)
                .background(book.isWantToRead ? Color.orange.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
                .clipShape(Circle())
                .overlay(Circle().stroke(book.isWantToRead ? Color.orange.opacity(0.3) : Color.secondary.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(book.isWantToRead ? "取消想读焦点" : "加入主页想读焦点 (最多4本)")
    }
    
    private func handleToggle() {
        if book.isWantToRead {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { book.isWantToRead = false }
        } else {
            do {
                let descriptor = FetchDescriptor<Book>(predicate: #Predicate<Book> { $0.isWantToRead == true })
                let currentCount = try modelContext.fetchCount(descriptor)
                if currentCount >= 4 {
                    NSSound.beep() // macOS 原生提示音
                    showMaxAlert = true
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { book.isWantToRead = true }
                }
            } catch { print("查询失败: \(error)") }
        }
    }
}

// MARK: - 8. 摘录与笔记展示墙 (BookExcerptsView)
private struct BookExcerptsView: View {
    let book: Book
    let isDeleteMode: Bool
    let onDelete: (RecordItem) -> Void
    
    private var mixedRecords: [RecordItem] {
        let excerpts = (book.excerpts ?? []).map { RecordItem.excerpt($0) }
        let notes = (book.notes ?? []).map { RecordItem.note($0) }
        return (excerpts + notes).sorted { $0.date > $1.date }
    }
    
    var body: some View {
        if mixedRecords.isEmpty {
            EmptyStateView()
        } else {
            let leftColumn = mixedRecords.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }
            let rightColumn = mixedRecords.enumerated().filter { $0.offset % 2 != 0 }.map { $0.element }
            
            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 24) {
                    ForEach(leftColumn) { item in
                        RecordCardWrapper(item: item, isDeleteMode: isDeleteMode) { onDelete(item) }
                    }
                }
                VStack(spacing: 24) {
                    ForEach(rightColumn) { item in
                        RecordCardWrapper(item: item, isDeleteMode: isDeleteMode) { onDelete(item) }
                    }
                }
            }
        }
    }
}

// 混合时间线模型
enum RecordItem: Identifiable {
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

// 记录包装器
private struct RecordCardWrapper: View {
    let item: RecordItem; let isDeleteMode: Bool; let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch item {
                case .excerpt(let excerpt): ExcerptCardView(excerpt: excerpt)
                case .note(let note): NoteCardView(note: note)
                }
            }
            if isDeleteMode {
                Button(action: onDelete) {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        .frame(width: 24, height: 24).background(Color.red).clipShape(Circle())
                        .shadow(color: Color.red.opacity(0.4), radius: 4, y: 2)
                }
                .buttonStyle(.plain).offset(x: 10, y: -10)
                .transition(.scale.combined(with: .opacity)).zIndex(1)
            }
        }
    }
}

// 摘录卡片
private struct ExcerptCardView: View {
    let excerpt: Excerpt
    var body: some View {
        let safeContent = excerpt.content ?? "无内容"
        let safeDate = excerpt.createdAt ?? Date()
        
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "quote.opening").font(.system(size: 32, weight: .black)).foregroundColor(Color.secondary.opacity(0.2))
            
            Text(LocalizedStringKey(safeContent))
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundColor(.primary).lineSpacing(8).fixedSize(horizontal: false, vertical: true)
                
            HStack {
                Spacer()
                Text("—— \(safeDate.formatted(date: .numeric, time: .shortened))").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary.opacity(0.6))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
    }
}

// 笔记卡片
private struct NoteCardView: View {
    let note: Note
    var body: some View {
        let safeContent = note.content ?? ""
        let safeDate = note.createdAt ?? Date()
        
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pencil.line").foregroundColor(.purple)
                Text("阅读笔记").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.secondary)
                Spacer()
                Text(safeDate.formatted(date: .numeric, time: .shortened)).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary.opacity(0.6))
            }
            
            Text(LocalizedStringKey(safeContent))
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .lineSpacing(6)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.orange.opacity(0.15), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
    }
}

// 空状态占位图
private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("没有任何思考的痕迹").font(.system(size: 16, weight: .bold)).foregroundColor(.secondary)
            Text("点击右上角的按钮，沉淀当下的思绪").font(.system(size: 13)).foregroundColor(.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity).frame(height: 200)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.secondary.opacity(0.1), style: StrokeStyle(lineWidth: 1.5, dash: [8, 8])))
    }
}
#endif
