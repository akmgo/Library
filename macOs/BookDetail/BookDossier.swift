#if os(macOS)
import SwiftUI
import SwiftData
import AppKit

// MARK: - ✨ 书籍核心信息档案板 (主视图)

struct BookDossier: View {
    @Bindable var book: Book
    @Namespace private var animationNamespace
    
    var body: some View {
        let safeTitle = book.title
        let safeAuthor = book.author
        
        VStack(alignment: .leading, spacing: 32) {
            HStack(alignment: .top, spacing: 40) {
                
                // 1. 左侧：3D 悬浮封面 (锁死 450 高度)
                InteractiveCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: safeTitle)
                    .frame(width: 300, height: 450)
                    .zIndex(2)
                
                // 2. 右侧：全景交互台
                VStack(alignment: .leading, spacing: 0) {
                    
                    // 顶部：书名、作者
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            HStack(alignment: .center, spacing: 16) {
                                Text(safeTitle)
                                    .font(.system(size: 36, weight: .black, design: .rounded))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                            }
                            
                            Spacer(minLength: 20)
                            
                            Text(safeAuthor)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(2)
                                .padding(.top, 8)
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    // 底部：三大核心信息卡片
                    VStack(alignment: .leading, spacing: 20) {
                        BookStatusPicker(book: book, animationNamespace: animationNamespace)
                        BookDatePickers(book: book)
                        BookRatingView(book: book)
                    }
                }
                .frame(height: 450)
                .frame(maxWidth: .infinity)
            }
            
            // 下方标签库
            BookTagsView(book: book)
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
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 16.0)) // ✨ 玻璃化
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("当前状态", systemImage: "book.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.blue)
            
            HStack(spacing: 0) {
                ForEach(AppConstants.statusOptions, id: \.0) { opt in
                    let isSelected = (book.status) == opt.0
                    Button(action: { handleStatusChange(to: opt.0) }) {
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.clear)
                                    .glassEffect(.regular.tint(.blue), in: .rect(cornerRadius: 10)) // ✨ 着色玻璃水滴
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
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 16.0)) // ✨ 外层卡片的液态玻璃
    }
    
    private func handleStatusChange(to newStatus: BookStatus) {
        let oldStatus = book.status
        let wasFinished = (oldStatus == .finished)
        let willFinish = (newStatus == .finished)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            book.status = newStatus
            let now = Date()
            
            if newStatus == .reading {
                if book.startDate == nil { book.startDate = now }
            } else if newStatus == .finished {
                if book.startDate == nil { book.startDate = now }
                // ✨ 恢复逻辑：切换到已读时，自动填充结束日期为当天
                if book.finishDate == nil { book.finishDate = now }
            }
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
                    AdvancedDatePickerButton(icon: "play.fill", title: "开始", date: $book.startDate)
                    AdvancedDatePickerButton(icon: "flag.fill", title: "结束", date: $book.finishDate, isDisabled: book.status != .finished)
                    
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
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 16.0)) // ✨ 外层面板玻璃化
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
                        Text(AppFormatters.numericDateFormatter.string(from: d))
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
                Label("知识标签库", systemImage: "tag.fill")
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
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 16.0)) // ✨ 外层卡片的液态玻璃
    }
}

// MARK: - ✨ 预览装配
struct BookDossierPreviewWrapper: View {
    @Query var books: [Book]
    var body: some View {
        if let book = books.first {
            BookDossier(book: book)
                .padding()
                .frame(width: 900)
        }
    }
}

#endif
