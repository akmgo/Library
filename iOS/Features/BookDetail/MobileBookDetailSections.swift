#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 基础结构

struct MobileBookIdentityHeader: View {
    let book: Book

    var body: some View {
        VStack(spacing: AppSpacing.s) {
            BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                .frame(width: 168, height: 252)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.14), radius: 18, y: 10)

            Text(book.title)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.top, AppSpacing.xs)

            Text(book.author.isEmpty ? "佚名" : book.author)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MobileBookDetailCard<Content: View, Trailing: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    let useClearGlassSurface: Bool
    let trailing: () -> Trailing
    let content: () -> Content

    init(
        title: String,
        systemImage: String,
        tint: Color,
        useClearGlassSurface: Bool = false,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.useClearGlassSurface = useClearGlassSurface
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        AppCard(usesClearMaterial: useClearGlassSurface) {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                DetailSectionHeader(title: title, systemImage: systemImage, tint: tint) {
                    trailing()
                }
                content()
            }
        }
    }
}

extension MobileBookDetailCard where Trailing == EmptyView {
    init(
        title: String,
        systemImage: String,
        tint: Color,
        useClearGlassSurface: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            tint: tint,
            useClearGlassSurface: useClearGlassSurface,
            trailing: { EmptyView() },
            content: content
        )
    }
}

// MARK: - 阅读状态

struct MobileReadingStatusCard: View {
    @Bindable var book: Book
    @Binding var showMaxAlert: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var selectedStatus: BookStatus?

    private var displayedStatus: BookStatus {
        selectedStatus ?? book.status
    }

    var body: some View {
        MobileBookDetailCard(
            title: "阅读状态",
            systemImage: "book.fill",
            tint: AppColors.selection,
        ) {
            AppSlidingSegmentedControl(
                selection: Binding(
                    get: { displayedStatus },
                    set: { handleStatusChange(to: $0) }
                ),
                options: AppConstants.statusOptions.map {
                    AppSlidingSegmentedOption(value: $0.0, title: $0.1)
                },
                tint: AppColors.selection,
                height: 34,
                cornerRadius: AppRadius.m,
                showsIcons: false
            )
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

        if newStatus == .planned {
            do {
                let plannedStatus = BookStatus.planned
                let descriptor = FetchDescriptor<Book>(
                    predicate: #Predicate<Book> { $0.status == plannedStatus }
                )
                let plannedBooks = try modelContext.fetch(descriptor)
                let plannedCount = plannedBooks.filter { $0.id != book.id }.count
                guard plannedCount < 4 else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    showMaxAlert = true
                    return
                }
            } catch {
                print("想读状态查询失败: \(error)")
            }
        }

        withAnimation(.easeOut(duration: 0.16)) {
            selectedStatus = newStatus
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard book.status != newStatus else { return }
            try? ReadingDataService.shared.updateStatus(book, to: newStatus, context: modelContext)
        }
    }
}

// MARK: - 日期

struct MobileReadingDateCard: View {
    @Bindable var book: Book

    private var totalDaysText: String {
        guard let startDate = book.startDate else { return "未开始" }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: book.finishDate ?? Date())
        let days = max(1, (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
        return "\(days) 天"
    }

    var body: some View {
        MobileBookDetailCard(
            title: "阅读旅程",
            systemImage: "calendar",
            tint: .mint,
            trailing: { AppCapsuleLabel(text: totalDaysText, tint: .mint) }
        ) {
            VStack(spacing: AppSpacing.s) {
                MobileDateControlRow(
                    icon: "calendar.badge.plus",
                    title: "开始",
                    date: $book.startDate,
                    tint: .mint,
                    isDisabled: book.status != .reading && book.status != .finished,
                    disabledText: "在读或已读后可设置"
                )
                MobileDateControlRow(
                    icon: "calendar.badge.checkmark",
                    title: "结束",
                    date: $book.finishDate,
                    tint: .mint,
                    isDisabled: book.status != .finished,
                    disabledText: "已读后可设置"
                )
            }
        }
    }
}

private struct MobileDateControlRow: View {
    let icon: String
    let title: String
    @Binding var date: Date?
    let tint: Color
    var isDisabled = false
    var disabledText = "不可设置"

    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: AppSpacing.s) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isDisabled ? .secondary.opacity(0.35) : tint)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill((isDisabled ? Color.secondary : tint).opacity(0.12)))

                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)

                Spacer()

                Text(displayText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(isDisabled ? .secondary.opacity(0.45) : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, AppSpacing.s)
            .frame(height: 48)
            .appInnerBlockStyle(cornerRadius: AppRadius.m)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .popover(isPresented: $showPicker) {
            DatePicker(
                "",
                selection: Binding(get: { date ?? Date() }, set: { date = $0 }),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .padding()
        }
    }

    private var displayText: String {
        if isDisabled { return disabledText }
        guard let date else { return "尚未设置" }
        return AppFormatters.chineseFullDateFormatter.string(from: date)
    }
}

// MARK: - 评价

struct MobileBookRatingCard: View {
    @Bindable var book: Book

    private let activeGradient = LinearGradient(
        colors: [.yellow, .orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        let validRating = min(max(book.rating, 0), 7)

        MobileBookDetailCard(
            title: "阅读沉淀",
            systemImage: "sparkles",
            tint: .yellow,
            trailing: {
                Text(AppConstants.ratingPoeticTexts[validRating])
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundStyle(validRating > 0 ? AnyShapeStyle(activeGradient) : AnyShapeStyle(Color.secondary.opacity(0.45)))
            }
        ) {
            HStack(spacing: 0) {
                ForEach(Array(1...7), id: \.self) { index in
                    let isFilled = index <= validRating
                    Image(systemName: isFilled ? "star.fill" : "star")
                        .font(.system(size: 23))
                        .foregroundStyle(isFilled ? AnyShapeStyle(activeGradient) : AnyShapeStyle(Color.secondary.opacity(0.18)))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeOut(duration: 0.14)) {
                                book.rating = validRating == index ? 0 : index
                            }
                        }
                }
            }
        }
    }
}

// MARK: - 标签

struct MobileBookTagsCard: View {
    @Bindable var book: Book
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [GridItem(.adaptive(minimum: 72, maximum: 120), spacing: AppSpacing.xs)]

    var body: some View {
        MobileBookDetailCard(
            title: "知识标签",
            systemImage: "tag.fill",
            tint: .purple,
            trailing: { AppCapsuleLabel(text: "\(book.tags.count) / 3", tint: .purple) }
        ) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: AppSpacing.xs) {
                ForEach(AppConstants.predefinedTags, id: \.self) { tag in
                    tagButton(tag)
                }
            }
        }
    }

    private func tagButton(_ tag: String) -> some View {
        let isSelected = book.tags.contains(tag)
        let isMaxed = book.tags.count >= 3 && !isSelected

        return Button {
            guard !isMaxed else { return }
            withAnimation(.easeOut(duration: 0.14)) {
                if isSelected {
                    book.tags.removeAll(where: { $0 == tag })
                } else {
                    book.tags.append(tag)
                }
            }
        } label: {
            Text(tag)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? .white : (isMaxed ? .secondary.opacity(0.45) : .primary))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous)
                            .fill(Color.purple)
                    } else {
                        RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous)
                            .fill(AppColors.innerBlock(for: colorScheme))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous)
                        .stroke(isSelected ? Color.clear : AppColors.innerStroke(for: colorScheme), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isMaxed)
    }
}

// MARK: - 阅读记录

struct MobileReadingSessionCard: View {
    let book: Book
    @State private var isExpanded = false
    private let maxCollapsed = 5

    private var snapshot: ReadingStatsCalculator.ReadingSessionListSnapshot {
        ReadingStatsCalculator.ReadingSessionListSnapshot(
            sessions: book.sessions ?? [],
            isExpanded: isExpanded,
            maxCollapsed: maxCollapsed
        )
    }

    var body: some View {
        MobileBookDetailCard(
            title: "阅读记录",
            systemImage: "clock.fill",
            tint: AppColors.readingAmber,
            trailing: {
                if !snapshot.isEmpty {
                    AppCapsuleLabel(text: "\(snapshot.totalCount) 条", tint: AppColors.readingAmber)
                }
            }
        ) {
            if snapshot.isEmpty {
                MobileEmptyDetailState(
                    systemImage: "clock.badge.questionmark",
                    title: "暂无阅读记录",
                    subtitle: "开始阅读或手动录入后，记录将显示在这里"
                )
            } else {
                MobileSessionRowsView(rows: snapshot.rows)
                    .equatable()
                .appInnerBlockStyle(cornerRadius: AppRadius.m)

                if snapshot.totalCount > maxCollapsed {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
                    } label: {
                        HStack(spacing: AppSpacing.xxs) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                            Text(isExpanded ? "收起" : "查看全部 \(snapshot.totalCount) 条记录")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xs)
                        .appInnerCapsuleStyle()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct MobileSessionRowsView: View, Equatable {
    let rows: [ReadingStatsCalculator.ReadingSessionRowSnapshot]

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                MobileSessionRowView(snapshot: row)
                if index < rows.count - 1 {
                    Divider().opacity(0.25)
                }
            }
        }
    }
}

private struct MobileSessionRowView: View, Equatable {
    let snapshot: ReadingStatsCalculator.ReadingSessionRowSnapshot

    var body: some View {
        ReadingSessionRowContent(snapshot: snapshot, layout: .compact)
    }
}

// MARK: - 摘录

struct MobileBookExcerptsCard: View {
    let book: Book
    @Binding var isDeleteMode: Bool
    let onDelete: (Excerpt) -> Void

    private var totalCount: Int {
        book.excerpts?.count ?? 0
    }

    var body: some View {
        MobileBookDetailCard(
            title: "摘录笔记",
            systemImage: "text.quote",
            tint: .teal,
            trailing: {
                if totalCount > 0 {
                    AppCapsuleLabel(text: "\(totalCount) 条", tint: .teal)
                }
            }
        ) {
            MobileBookExcerptsList(book: book, isDeleteMode: isDeleteMode, onDelete: onDelete)
        }
    }
}

private struct MobileEmptyDetailState: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.secondary.opacity(0.4))
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.55))
            Text(subtitle)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.38))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.l)
    }
}


#if DEBUG
private struct PreviewDetailComponents: View {
    @State private var showMax = false
    @State private var isDeleteMode = false
    var body: some View {
        PreviewWithBook { book in
            NavigationStack {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.l) {
                        MobileBookIdentityHeader(book: book)
                        MobileReadingStatusCard(book: book, showMaxAlert: $showMax)
                        MobileReadingDateCard(book: book)
                        MobileBookRatingCard(book: book)
                        MobileBookTagsCard(book: book)
                        MobileReadingSessionCard(book: book)
                        MobileBookExcerptsCard(book: book, isDeleteMode: $isDeleteMode, onDelete: { _ in })
                    }
                    .padding(AppSpacing.l)
                }
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
