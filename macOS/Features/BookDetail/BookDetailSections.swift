#if os(macOS)
import SwiftUI
import SwiftData
import AppKit

// MARK: - ✨ 书籍核心信息档案板 (主视图)

struct BookDetailSections: View {
    @Bindable var book: Book
    @Binding var isDeleteMode: Bool
    var onDeleteExcerpt: (Excerpt) -> Void

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
                        BookStatusPicker(book: book)
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
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.8))
                    .frame(width: size.width, height: size.height)
                    .shadow(
                        color: Color.black.opacity(0.15),
                        radius: 20,
                        x: 0,
                        y: 15
                    )
                
                BookCoverView(coverID: coverID, coverData: coverData, fallbackTitle: fallbackTitle)
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                    )
            }
            .frame(width: size.width, height: size.height)
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
        
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
            DetailSectionHeader(title: "阅读沉淀", systemImage: "sparkles", tint: .yellow) {
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
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleRatingTap(tappedIndex: index, currentRating: validRating)
                        }
                }
            }
            .padding(.top, 4)
        }
        }
    }

    private func handleRatingTap(tappedIndex: Int, currentRating: Int) {
        withAnimation(.appControlFeedback) {
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
    @Environment(\.modelContext) private var modelContext
    @State private var selectedStatus: BookStatus?

    private var displayedStatus: BookStatus {
        selectedStatus ?? book.status
    }
    
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
            DetailSectionHeader(title: "当前状态", systemImage: "book.fill", tint: AppColors.selection)
            
            AppSlidingSegmentedControl(
                selection: Binding(
                    get: { displayedStatus },
                    set: { handleStatusChange(to: $0) }
                ),
                options: AppConstants.statusOptions.map {
                    AppSlidingSegmentedOption(value: $0.0, title: $0.1)
                },
                tint: AppColors.selection,
                height: 36,
                cornerRadius: 12,
                showsIcons: false
            )
        }
        }
        .onAppear {
            selectedStatus = book.status
        }
        .onChange(of: book.status) { _, newValue in
            if selectedStatus != newValue {
                selectedStatus = newValue
            }
        }
    }

    private func handleStatusChange(to newStatus: BookStatus) {
        guard newStatus != displayedStatus else { return }

        withAnimation(.appControlFeedback) {
            selectedStatus = newStatus
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard book.status != newStatus else { return }
            book.status = newStatus
            do {
                try modelContext.save()
            } catch {
                print("状态保存失败: \(error.localizedDescription)")
            }
        }

    }
}

// MARK: - 子组件：高级日期选择器矩阵

struct BookDatePickers: View {
    @Bindable var book: Book

    private var totalDays: Int? {
        guard let start = book.startDate else { return nil }
        let calendar = Calendar.current
        let end = book.finishDate ?? Date()
        let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0
        return max(1, diff + 1)
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
            DetailSectionHeader(title: "阅读旅程", systemImage: "calendar", tint: .mint) {
                if let days = totalDays {
                    AppCapsuleLabel(text: "\(days) 天", tint: .mint)
                }
            }

            HStack(spacing: 14) {
                AdvancedDatePickerButton(
                    icon: "calendar.badge.plus",
                    title: "开始",
                    date: $book.startDate,
                    isDisabled: book.status != .reading && book.status != .finished,
                    disabledText: "在读或已读后可设置"
                )
                AdvancedDatePickerButton(
                    icon: "calendar.badge.checkmark",
                    title: "结束",
                    date: $book.finishDate,
                    isDisabled: book.status != .finished,
                    disabledText: "已读后可设置"
                )
            }
        }
        }
    }
}

struct AdvancedDatePickerButton: View {
    let icon: String; let title: String; @Binding var date: Date?; var isDisabled: Bool = false; var disabledText = "不可设置"
    @State private var isShowingPopover = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: { withAnimation(.appControlFeedback) { isShowingPopover.toggle() } }) {
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
                            .foregroundColor(isDisabled ? .secondary.opacity(0.45) : .primary)
                    } else {
                        Text(isDisabled ? disabledText : "尚未设置")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity)
            .background(AppColors.innerBlock(for: colorScheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.innerStroke(for: colorScheme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain).disabled(isDisabled).opacity(isDisabled ? 0.4 : 1.0)
        .popover(isPresented: $isShowingPopover, arrowEdge: Edge.bottom) { ScreenshotStyleDatePicker(selectedDate: $date) }
    }
}

struct ScreenshotStyleDatePicker: View {
    @Binding var selectedDate: Date?
    @Environment(\.colorScheme) private var colorScheme
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
        .frame(width: 280)
        .background(AppColors.primaryBackground(for: colorScheme))
    }
    private func isToday(_ date: Date?) -> Bool { guard let date = date else { return false }; return Calendar.current.isDateInToday(date) }
}

struct QuickOptionRow: View {
    let icon: String; let iconColor: Color; let title: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(iconColor).frame(width: 20)
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                if isSelected { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundColor(.blue) }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.clear)
            .cornerRadius(8).padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 子组件：标签库

struct BookTagsView: View {
    @Bindable var book: Book
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        AppCard {
            let safeTags: [String] = book.tags
            VStack(alignment: .leading, spacing: 20) {
            DetailSectionHeader(title: "知识标签", systemImage: "tag.fill", tint: .purple) {
                AppCapsuleLabel(text: "\(safeTags.count) / 3", tint: .purple)
            }
            let columns = [GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 12)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(AppConstants.predefinedTags, id: \.self) { tag in
                    let isSelected = safeTags.contains(tag)
                    let isMaxed = safeTags.count >= 3 && !isSelected
                    
                    Button(action: {
                        withAnimation(.appControlFeedback) {
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
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected ? Color.purple : AppColors.innerBlock(for: colorScheme))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isSelected ? Color.clear : AppColors.innerStroke(for: colorScheme), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain).disabled(isMaxed)
                }
            }
        }
        }
    }
}

// MARK: - ✨ 阅读记录卡片

struct ReadingSessionCard: View {
    let book: Book

    @State private var isExpanded = false
    private let maxCollapsed = 10

    private var snapshot: ReadingStatsCalculator.ReadingSessionListSnapshot {
        ReadingStatsCalculator.ReadingSessionListSnapshot(
            sessions: book.sessions ?? [],
            isExpanded: isExpanded,
            maxCollapsed: maxCollapsed
        )
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
            DetailSectionHeader(title: "阅读记录", systemImage: "clock.fill", tint: AppColors.readingAmber) {
                if !snapshot.isEmpty {
                    AppCapsuleLabel(text: "\(snapshot.totalCount) 条", tint: AppColors.readingAmber)
                }
            }

            if snapshot.isEmpty {
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
                SessionRowsView(rows: snapshot.rows)
                    .equatable()
                .appInnerBlockStyle(cornerRadius: AppRadius.m)

                if snapshot.totalCount > maxCollapsed {
                    Button {
                        withAnimation(.appContentFade) { isExpanded.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                            Text(isExpanded ? "收起" : "查看全部 \(snapshot.totalCount) 条记录")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .appInnerCapsuleStyle()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        }
    }
}

// MARK: - ✨ 单行阅读记录

private struct SessionRowsView: View, Equatable {
    let rows: [ReadingStatsCalculator.ReadingSessionRowSnapshot]

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                SessionRowView(snapshot: row)
                if index < rows.count - 1 {
                    Divider().opacity(0.25).padding(.leading, 12)
                }
            }
        }
    }
}

private struct SessionRowView: View, Equatable {
    let snapshot: ReadingStatsCalculator.ReadingSessionRowSnapshot

    var body: some View {
        ReadingSessionRowContent(snapshot: snapshot, layout: .regular)
    }
}

// MARK: - ✨ 摘录笔记卡片

struct ExcerptCard: View {
    let book: Book
    @Binding var isDeleteMode: Bool
    var onDelete: (Excerpt) -> Void

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
            DetailSectionHeader(title: "摘录笔记", systemImage: "text.quote", tint: .teal) {
                let total = book.excerpts?.count ?? 0
                if total > 0 {
                    AppCapsuleLabel(text: "\(total) 条", tint: .teal)
                }
            }

            BookExcerpts(book: book, isDeleteMode: isDeleteMode, onDelete: onDelete)
        }
        }
    }
}

// MARK: - ✨ 预览装配
struct BookDetailSectionsPreviewWrapper: View {
    @Query var books: [Book]
    @State private var isDeleteMode = false
    var body: some View {
        if let book = books.first {
            BookDetailSections(book: book, isDeleteMode: $isDeleteMode, onDeleteExcerpt: { _ in })
                .padding()
                .frame(width: 900)
        }
    }
}

#endif
