#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 🧩 右侧超紧凑组件：想读标记按钮

struct MobilePlannedStatusToggle: View {
    @Bindable var book: Book
    @Binding var showMaxAlert: Bool
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Button {
            handleToggle()
        } label: {
            // ✨ 修复：彻底弃用布尔值，改用原生状态枚举判定
            let isPlanned = book.status == .planned
            Image(systemName: isPlanned ? "bookmark.fill" : "bookmark")
                .font(.system(size: 16))
                .foregroundColor(isPlanned ? .orange : Color.gray.opacity(0.5))
                .padding(4)
        }
        .buttonStyle(.plain)
    }
    
    private func handleToggle() {
        if book.status == .planned {
            withAnimation(.spring()) {
                try? ReadingDataService.shared.updateStatus(book, to: .unread, context: modelContext)
            }
        } else {
            do {
                // ✨ 安全过滤：在内存中过滤以防 #Predicate 引起 SQLite 崩溃
                let allBooks = try modelContext.fetch(FetchDescriptor<Book>())
                let count = allBooks.filter { $0.status == .planned }.count
                
                if count >= 4 {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    showMaxAlert = true
                } else {
                    withAnimation(.spring()) {
                        try? ReadingDataService.shared.updateStatus(book, to: .planned, context: modelContext)
                    }
                }
            } catch { print("想读状态查询失败: \(error)") }
        }
    }
}

// MARK: - 🧩 右侧超紧凑组件：状态选择器

struct MobileCompactStatusPicker: View {
    @Bindable var book: Book
    var animationNamespace: Namespace.ID
    @Environment(\.modelContext) private var modelContext
    
    // “想读”不放在选择器里，靠书签按钮触发，所以这里只放核心三态
    let options: [(BookStatus, String)] = [(.unread, "待读"), (.reading, "在读"), (.finished, "已读完")]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { opt in
                let isSelected = book.status == opt.0
                Button(action: {
                    handleStatusChange(to: opt.0)
                }) {
                    ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(AppColors.selection)
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
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            try? ReadingDataService.shared.updateStatus(book, to: newStatus, context: modelContext)
        }
    }
}

// MARK: - 🧩 右侧超紧凑组件：双列日期与历时区块

struct MobileCompactDatePickers: View {
    @Bindable var book: Book
    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            VStack(spacing: 6) {
                CompactDateBtn(icon: "play.fill", title: "开始", date: $book.startDate)
                CompactDateBtn(icon: "flag.fill", title: "结束", date: $book.finishDate, isDisabled: book.status != .finished)
            }
            
            if book.status == .finished, let start = book.startDate, let end = book.finishDate {
                let days = max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1)
                VStack(spacing: 2) {
                    Text("\(days)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.success)
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
            .background(Color.secondary.opacity(0.1))
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

struct MobileCompactRatingView: View {
    @Bindable var book: Book

    var body: some View {
        let validRating = min(max(book.rating, 0), 7)
        HStack(spacing: AppSpacing.xxs) {
            HStack(spacing: 1) {
                ForEach(1 ... 7, id: \.self) { star in
                    let isFilled = validRating >= star
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundColor(isFilled ? .yellow : Color.secondary.opacity(0.2))
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3)) { book.rating = star }
                        }
                }
            }
            Spacer()
            if validRating > 0 {
                Text(AppConstants.ratingPoeticTexts[validRating])
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .foregroundColor(AppColors.readingAmber)
            } else {
                Text("暂无评价").font(.system(size: 10, weight: .medium)).foregroundColor(Color.gray.opacity(0.5))
            }
        }
    }
}

// MARK: - 🧩 底部超紧凑组件：自适应多行标签网格

struct MobileCompactTagsView: View {
    @Bindable var book: Book
    let predefinedTags = ["哲学", "历史", "商业", "科技", "文学", "成长", "设计", "心理", "传记", "管理"]
    
    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 54, maximum: 70), spacing: AppSpacing.xs)]
        
        LazyVGrid(columns: columns, alignment: .leading, spacing: AppSpacing.xs) {
            ForEach(predefinedTags, id: \.self) { tag in
                let isSelected = book.tags.contains(tag)
                let isMaxed = book.tags.count >= 3 && !isSelected
                
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        // ✨ 修复：非可选数组的丝滑操作
                        if isSelected {
                            book.tags.removeAll(where: { $0 == tag })
                        } else if book.tags.count < 3 {
                            book.tags.append(tag)
                        }
                    }
                }) {
                    Text(tag)
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(isSelected ? Color.indigo : Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .disabled(isMaxed)
                .opacity(isMaxed ? 0.4 : 1.0)
            }
        }
    }
}
// MARK: - 阅读记录卡片

struct MobileReadingSessionCard: View {
    let book: Book
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false
    private let maxCollapsed = 5

    private var sessions: [ReadingSession] {
        (book.sessions ?? []).sorted { $0.startedAt > $1.startedAt }
    }

    var body: some View {
        let visible = isExpanded ? sessions : Array(sessions.prefix(maxCollapsed))
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack {
                Label("阅读记录", systemImage: "clock.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppColors.readingAmber)
                Spacer()
                if !sessions.isEmpty {
                    Text("\(sessions.count) 条")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
            }

            if sessions.isEmpty {
                HStack {
                    Spacer()
                    Text("暂无阅读记录").font(.system(size: 13)).foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { i, s in
                        HStack(spacing: AppSpacing.s) {
                            Text(s.startedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.primary)
                                .frame(width: 72, alignment: .leading)
                            Text(s.displayDuration)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.readingAmber)
                            Spacer()
                            if s.deltaAmount > 0 {
                                Text(s.displayDelta)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.readingAmber)
                            }
                        }
                        .padding(.vertical, AppSpacing.xs)
                        if i < visible.count - 1 {
                            Divider().opacity(0.3)
                        }
                    }
                }
                .padding(AppSpacing.s)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if sessions.count > maxCollapsed {
                    Button(action: { withAnimation { isExpanded.toggle() } }) {
                        Text(isExpanded ? "收起" : "查看全部 \(sessions.count) 条")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(AppSpacing.m)
        .background(AppColors.secondaryBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
        .padding(.horizontal, AppSpacing.m)
    }
}


#if DEBUG
private struct PreviewDetailComponents: View {
    @State private var showMax = false
    var body: some View {
        PreviewWithBook { book in
            NavigationStack {
                VStack(spacing: 20) {
                    MobileCompactRatingView(book: book)
                    MobileCompactTagsView(book: book)
                    MobilePlannedStatusToggle(book: book, showMaxAlert: $showMax)
                }
                .padding()
            }
        }
        .modelContainer(previewModelContainer)
    }
}

#Preview("详情组件") {
    PreviewDetailComponents()
}
#endif


#endif
