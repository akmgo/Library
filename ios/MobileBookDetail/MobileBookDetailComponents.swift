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
    let trailing: () -> Trailing
    let content: () -> Content

    init(
        title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack(spacing: AppSpacing.s) {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(tint)
                Spacer(minLength: AppSpacing.s)
                trailing()
            }
            content()
        }
        .padding(AppSpacing.l)
        .readingRecordCardStyle()
    }
}

extension MobileBookDetailCard where Trailing == EmptyView {
    init(
        title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(title: title, systemImage: systemImage, tint: tint, trailing: { EmptyView() }, content: content)
    }
}

private struct MobileCountBadge: View {
    let text: String
    var tint: Color?

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.secondary))
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint?.opacity(0.14) ?? Color.primary.opacity(0.08)))
    }
}

// MARK: - 阅读状态

struct MobileReadingStatusCard: View {
    @Bindable var book: Book
    @Binding var showMaxAlert: Bool

    @Environment(\.modelContext) private var modelContext
    @Namespace private var animationNamespace

    var body: some View {
        MobileBookDetailCard(title: "阅读状态", systemImage: "book.fill", tint: AppColors.selection) {
            HStack(spacing: 0) {
                ForEach(AppConstants.statusOptions, id: \.0) { option in
                    statusButton(status: option.0, title: option.1)
                }
            }
            .padding(4)
            .background(Color.primary.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous))
        }
    }

    private func statusButton(status: BookStatus, title: String) -> some View {
        let isSelected = book.status == status
        return Button {
            handleStatusChange(to: status)
        } label: {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: AppRadius.s, style: .continuous)
                        .fill(AppColors.selection)
                        .matchedGeometryEffect(id: "mobile-book-status", in: animationNamespace)
                }
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func handleStatusChange(to newStatus: BookStatus) {
        guard newStatus != book.status else { return }

        if newStatus == .planned {
            do {
                let allBooks = try modelContext.fetch(FetchDescriptor<Book>())
                let plannedCount = allBooks.filter { $0.id != book.id && $0.status == .planned }.count
                guard plannedCount < 4 else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    showMaxAlert = true
                    return
                }
            } catch {
                print("想读状态查询失败: \(error)")
            }
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.18)) {
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
            trailing: { MobileCountBadge(text: totalDaysText, tint: .mint) }
        ) {
            VStack(spacing: AppSpacing.s) {
                MobileDateControlRow(icon: "calendar.badge.plus", title: "开始", date: $book.startDate, tint: .mint)
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
            .background(Color.primary.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous))
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
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
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

    private let columns = [GridItem(.adaptive(minimum: 72, maximum: 120), spacing: AppSpacing.xs)]

    var body: some View {
        MobileBookDetailCard(
            title: "知识标签",
            systemImage: "tag.fill",
            tint: .purple,
            trailing: { MobileCountBadge(text: "\(book.tags.count) / 3") }
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
            withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
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
                .background(isSelected ? Color.purple : Color.primary.opacity(0.045))
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

    private var sessions: [ReadingSession] {
        (book.sessions ?? []).sorted { $0.startedAt > $1.startedAt }
    }

    private var visibleSessions: [ReadingSession] {
        isExpanded ? sessions : Array(sessions.prefix(maxCollapsed))
    }

    var body: some View {
        MobileBookDetailCard(
            title: "阅读记录",
            systemImage: "clock.fill",
            tint: AppColors.readingAmber,
            trailing: {
                if !sessions.isEmpty {
                    MobileCountBadge(text: "\(sessions.count) 条")
                }
            }
        ) {
            if sessions.isEmpty {
                MobileEmptyDetailState(
                    systemImage: "clock.badge.questionmark",
                    title: "暂无阅读记录",
                    subtitle: "开始阅读或手动录入后，记录将显示在这里"
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visibleSessions.enumerated()), id: \.element.id) { index, session in
                        MobileSessionRowView(session: session)
                        if index < visibleSessions.count - 1 {
                            Divider().opacity(0.25)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                        .fill(Color.primary.opacity(0.025))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )

                if sessions.count > maxCollapsed {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
                    } label: {
                        HStack(spacing: AppSpacing.xxs) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                            Text(isExpanded ? "收起" : "查看全部 \(sessions.count) 条记录")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Capsule().fill(Color.primary.opacity(0.04)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct MobileSessionRowView: View {
    let session: ReadingSession

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppFormatters.chineseFullDateFormatter.string(from: session.startedAt))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(session.displayTimeRange)
                    .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(session.displayDuration)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.readingAmber)
                HStack(spacing: 6) {
                    if session.deltaAmount > 0 {
                        Text(session.displayDelta)
                    }
                    Text(session.inputMode == .timer ? "计时" : "手动")
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.65))
            }
        }
        .padding(.horizontal, AppSpacing.s)
        .padding(.vertical, AppSpacing.s)
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
                    MobileCountBadge(text: "\(totalCount) 条")
                }
            }
        ) {
            MobileExcerptsAndNotesList(book: book, isDeleteMode: isDeleteMode, onDelete: onDelete)
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
                    VStack(spacing: AppSpacing.l) {
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
