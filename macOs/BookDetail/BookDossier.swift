#if os(macOS)
import SwiftUI
import SwiftData
import AppKit

// MARK: - ✨ 书籍核心信息档案板 (主视图)

struct BookDossier: View {
    @Bindable var book: Book
    @Binding var isDeleteMode: Bool
    var onDeleteExcerpt: (Excerpt) -> Void
    @Namespace private var animationNamespace

    var body: some View {
        let safeTitle = book.title
        let safeAuthor = book.author

        VStack(alignment: .leading, spacing: 32) {
            HStack(alignment: .top, spacing: 48) {

                // 1. 左侧：3D 悬浮封面
                InteractiveCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: safeTitle)
                    .frame(width: 360, height: 540)
                    .zIndex(2)

                // 2. 右侧：全景交互台
                VStack(alignment: .leading, spacing: 0) {

                    // 顶部：书名、作者
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            HStack(alignment: .center, spacing: 16) {
                                Text(safeTitle)
                                    .font(.system(size: 44, weight: .black, design: .rounded))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                            }

                            Spacer(minLength: 24)

                            Text(safeAuthor)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(2)
                                .padding(.top, 10)
                        }
                    }

                    Spacer(minLength: 0)

                    // 底部：三大核心信息卡片
                    VStack(alignment: .leading, spacing: 28) {
                        BookStatusPicker(book: book, animationNamespace: animationNamespace)
                        BookDatePickers(book: book)
                        BookRatingView(book: book)
                    }
                }
                .frame(height: 540)
                .frame(maxWidth: .infinity)
            }

            // 下方标签库
            BookTagsView(book: book)

            // 阅读记录
            ReadingSessionCard(book: book)

            // 摘录笔记
            ExcerptCard(book: book, isDeleteMode: $isDeleteMode, onDelete: onDeleteExcerpt)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ✨ 3D 悬浮封面引擎

struct InteractiveCoverView: View {
    let coverID: String
    let coverData: Data?
    let fallbackTitle: String
    
    @State private var hoverLocation: CGPoint? = nil
    @State private var isHovering: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            
            let hoverX = hoverLocation?.x ?? center.x
            let hoverY = hoverLocation?.y ?? center.y
            let normalizedX = (hoverX - center.x) / (size.width / 2)
            let normalizedY = (hoverY - center.y) / (size.height / 2)
            
            let pitch = isHovering ? -normalizedY * 8 : 0
            let yaw = isHovering ? normalizedX * 8 : 0
            
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.8))
                    .frame(width: size.width, height: size.height)
                    .shadow(
                        color: Color.black.opacity(isHovering ? 0.25 : 0.15),
                        radius: isHovering ? 30 : 20,
                        x: isHovering ? -normalizedX * 15 : 0,
                        y: isHovering ? -normalizedY * 15 + 20 : 15
                    )
                
                BookCoverView(coverID: coverID, coverData: coverData, fallbackTitle: fallbackTitle)
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(isHovering ? 0.15 : 0.05), lineWidth: 0.5)
                    )
            }
            .frame(width: size.width, height: size.height)
            .rotation3DEffect(
                .degrees(isHovering ? 1.0 : 0.0),
                axis: (x: pitch, y: yaw, z: 0)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isHovering)
            .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: hoverLocation)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    isHovering = true; hoverLocation = location
                case .ended:
                    isHovering = false; hoverLocation = nil
                }
            }
        }
    }
}

// MARK: - ✨ 七重诗意沉淀系统 (液态玻璃卡片)

struct BookRatingView: View {
    @Bindable var book: Book
    
    let activeGradient = LinearGradient(
        colors: [.yellow, .orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        let safeRating = book.rating
        let validRating = min(max(safeRating, 0), 7)
        
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Label("阅读沉淀", systemImage: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.yellow)
                
                Spacer()
                
                Text(AppConstants.ratingPoeticTexts[validRating])
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundStyle(validRating > 0 ? AnyShapeStyle(activeGradient) : AnyShapeStyle(Color.secondary.opacity(0.4)))
                    .tracking(1)
                    .contentTransition(.opacity)
            }
            
            HStack(spacing: 0) {
                ForEach(1...7, id: \.self) { index in
                    Image(systemName: index <= validRating ? "star.fill" : "star")
                        .font(.system(size: 20))
                        .foregroundStyle(index <= validRating ? AnyShapeStyle(activeGradient) : AnyShapeStyle(Color.secondary.opacity(0.15)))
                        .shadow(color: index <= validRating ? Color.orange.opacity(0.4) : .clear, radius: 4)
                        .scaleEffect(index <= validRating ? 1.08 : 1.0)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleRatingTap(tappedIndex: index, currentRating: validRating)
                        }
                        .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                }
            }
            .padding(.top, 4)
        }
        .glassCard()
    }

    private func handleRatingTap(tappedIndex: Int, currentRating: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            if currentRating == tappedIndex {
                book.rating = 0
            } else {
                book.rating = tappedIndex
            }
        }
    }
}

// MARK: - 子组件：状态选择器

struct BookStatusPicker: View {
    @Bindable var book: Book
    var animationNamespace: Namespace.ID
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("当前状态", systemImage: "book.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(AppColors.selection)
            
            HStack(spacing: 0) {
                ForEach(AppConstants.statusOptions, id: \.0) { opt in
                    let isSelected = (book.status) == opt.0
                    Button(action: { handleStatusChange(to: opt.0) }) {
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.clear)
                                    .glassEffect(.regular.tint(AppColors.selection), in: .rect(cornerRadius: 10)) // ✨ 着色玻璃水滴
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
            .background(Color.clear.glassEffect(in: .rect(cornerRadius: 12.0))) // ✨ 内部轨道的底层玻璃
        }
        .glassCard()
    }

    private func handleStatusChange(to newStatus: BookStatus) {
        let oldStatus = book.status
        let wasFinished = (oldStatus == .finished)
        let willFinish = (newStatus == .finished)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            try? ReadingDataService.shared.updateStatus(book, to: newStatus, context: modelContext)
        }
        
        if willFinish && !wasFinished {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: Notification.Name.triggerConfetti, object: nil)
            }
        }
    }
}

// MARK: - 子组件：高级日期选择器矩阵

struct BookDatePickers: View {
    @Bindable var book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("阅读旅程", systemImage: "calendar")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.mint)
            
            HStack(spacing: 16) {
                if book.status == .unread || book.status == .planned {
                    Text("等待翻开第一页...")
                        .font(.system(size: 14, weight: .medium, design: .serif)).italic()
                        .foregroundColor(.secondary)
                        .frame(height: 56)
                    Spacer()
                } else {
                    AdvancedDatePickerButton(icon: "calendar.badge.plus", title: "开始", date: $book.startDate)
                    AdvancedDatePickerButton(icon: "calendar.badge.checkmark", title: "结束", date: $book.finishDate, isDisabled: book.status != .finished)
                    
                    if book.status == .finished, let start = book.startDate, let end = book.finishDate {
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
                        .glassEffect(in: .rect(cornerRadius: 12.0)) // ✨ 历时小卡片玻璃化
                        .transition(.scale.combined(with: .opacity))
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .glassCard()
    }
}

struct AdvancedDatePickerButton: View {
    let icon: String; let title: String; @Binding var date: Date?; var isDisabled: Bool = false
    @State private var isShowingPopover = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isShowingPopover.toggle() } }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(date != nil ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1)).frame(width: 36, height: 36)
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(date != nil ? .blue : .secondary)
                }
                HStack(spacing: 10) {
                    Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                    if let d = date {
                        Text(AppFormatters.chineseFullDateFormatter.string(from: d))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    } else {
                        Text("尚未设置")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity)
            // ✨ 按钮本身变成一层带有交互反馈的玻璃
            .glassEffect(isHovered ? .regular.interactive() : .clear.interactive(), in: .rect(cornerRadius: 12.0))
        }
        .buttonStyle(.plain).disabled(isDisabled).opacity(isDisabled ? 0.4 : 1.0)
        .onHover { h in withAnimation(.easeInOut(duration: 0.2)) { isHovered = h }; if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        .popover(isPresented: $isShowingPopover, arrowEdge: Edge.bottom) { ScreenshotStyleDatePicker(selectedDate: $date) }
    }
}

struct ScreenshotStyleDatePicker: View {
    @Binding var selectedDate: Date?
    var customCalendar: Calendar { var cal = Calendar.current; cal.firstWeekday = 2; return cal }
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
                .environment(\.calendar, customCalendar).environment(\.locale, Locale(identifier: "zh_CN"))
                .scaleEffect(1.5).frame(width: 250, height: 260).padding(.horizontal, 24).padding(.bottom, 20)
        }
        .frame(width: 280).background(Color(nsColor: .windowBackgroundColor))
    }
    private func isToday(_ date: Date?) -> Bool { guard let date = date else { return false }; return Calendar.current.isDateInToday(date) }
}

struct QuickOptionRow: View {
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
            .background(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
            .cornerRadius(8).padding(.horizontal, 8)
        }
        .buttonStyle(.plain).onHover { h in isHovered = h; if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
    }
}

// MARK: - 子组件：标签库

struct BookTagsView: View {
    @Bindable var book: Book
    
    var body: some View {
        let safeTags: [String] = book.tags
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("知识标签", systemImage: "tag.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.purple)
                Spacer()
                Text("\(safeTags.count) / 3").font(.system(size: 14, weight: .bold)).foregroundColor(.secondary)
            }
            let columns = [GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 12)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(AppConstants.predefinedTags, id: \.self) { tag in
                    let isSelected = safeTags.contains(tag)
                    let isMaxed = safeTags.count >= 3 && !isSelected
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            var currentTags = book.tags
                            if isSelected { currentTags.removeAll(where: { $0 == tag }) }
                            else if currentTags.count < 3 { currentTags.append(tag) }
                            book.tags = currentTags
                        }
                    }) {
                        Text(tag)
                            .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .white : (isMaxed ? .secondary.opacity(0.6) : .primary))
                            .frame(height: 36).frame(maxWidth: .infinity)
                            // ✨ 亮点：选中的标签变成一颗紫色的液态水滴！
                            .glassEffect(isSelected ? .regular.tint(.purple).interactive() : .clear.interactive(), in: .rect(cornerRadius: 12.0))
                            .scaleEffect(isSelected ? 1.05 : 1.0)
                    }
                    .buttonStyle(.plain).disabled(isMaxed).onHover { h in if h && !isMaxed { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                }
            }
        }
        .glassCard()
    }
}

// MARK: - ✨ 阅读记录卡片

struct ReadingSessionCard: View {
    let book: Book

    @State private var isExpanded = false
    private let maxCollapsed = 10

    private var sessions: [ReadingSession] {
        (book.sessions ?? []).sorted { $0.startedAt > $1.startedAt }
    }

    private var visibleSessions: [ReadingSession] {
        isExpanded ? sessions : Array(sessions.prefix(maxCollapsed))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("阅读记录", systemImage: "clock.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppColors.readingAmber)

                Spacer()

                if !sessions.isEmpty {
                    Text("\(sessions.count) 条")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
            }

            if sessions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.secondary.opacity(0.4))
                    Text("暂无阅读记录")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("开始阅读或手动录入后，记录将显示在这里")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.35))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visibleSessions.enumerated()), id: \.element.id) { index, session in
                        SessionRowView(session: session)
                        if index < visibleSessions.count - 1 {
                            Divider().opacity(0.25).padding(.leading, 12)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                        .fill(Color.primary.opacity(0.02))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )

                if sessions.count > maxCollapsed {
                    Button {
                        withAnimation(.appContentFade) { isExpanded.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                            Text(isExpanded ? "收起" : "查看全部 \(sessions.count) 条记录")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.primary.opacity(0.04)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .glassCard()
    }
}

// MARK: - ✨ 单行阅读记录

private struct SessionRowView: View {
    let session: ReadingSession

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月d日"
        return f
    }()

    var body: some View {
        HStack(spacing: 20) {
            Text(dateFormatter.string(from: session.startedAt))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 124, alignment: .leading)

            Text(session.displayTimeRange)
                .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(session.displayDuration)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.readingAmber)
                .frame(width: 80, alignment: .leading)

            if session.deltaAmount > 0 {
                Text(session.displayDelta)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.readingAmber)
                    .frame(width: 64, alignment: .leading)
            } else {
                Spacer().frame(width: 64)
            }

            Spacer()

            HStack(spacing: 3) {
                Image(systemName: session.inputMode == .timer ? "timer" : "hand.raised")
                    .font(.system(size: 9))
                Text(session.inputMode == .timer ? "计时" : "手动")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.secondary.opacity(0.5))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.primary.opacity(0.05)))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}

// MARK: - ✨ 摘录笔记卡片

struct ExcerptCard: View {
    let book: Book
    @Binding var isDeleteMode: Bool
    var onDelete: (Excerpt) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("摘录笔记", systemImage: "text.quote")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.teal)

                Spacer()

                let total = book.excerpts?.count ?? 0
                if total > 0 {
                    Text("\(total) 条")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
            }

            BookExcerpts(book: book, isDeleteMode: isDeleteMode, onDelete: onDelete)
        }
        .glassCard()
    }
}

// MARK: - ✨ 预览装配
struct BookDossierPreviewWrapper: View {
    @Query var books: [Book]
    @State private var isDeleteMode = false
    var body: some View {
        if let book = books.first {
            BookDossier(book: book, isDeleteMode: $isDeleteMode, onDeleteExcerpt: { _ in })
                .padding()
                .frame(width: 900)
        }
    }
}

#endif
