#if os(macOS) || os(iOS)
import SwiftUI

struct YearlyTimelineBookCardContent: View {
    let book: Book
    var isMirrored: Bool = false
    var coverWidth: CGFloat = 100

    /// 严格按 2:3 比例从宽度推导高度，保证封面比例始终正确。
    private var coverHeight: CGFloat { coverWidth * 1.5 }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.l) {
            if isMirrored {
                textSection
                coverSection
            } else {
                coverSection
                textSection
            }
        }
    }

    private var coverSection: some View {
        BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
            .frame(width: coverWidth, height: coverHeight)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.14), radius: 6, y: 3)
    }

    private var textSection: some View {
        VStack(alignment: isMirrored ? .trailing : .leading, spacing: AppSpacing.s) {
            VStack(alignment: isMirrored ? .trailing : .leading, spacing: 4) {
                titleText
                authorText
            }

            ratingView
            tagView

            Spacer(minLength: 0)

            YearlyTimelineJourneyTicket(book: book, isMirrored: isMirrored)
        }
        .frame(maxWidth: .infinity, alignment: isMirrored ? .trailing : .leading)
        .frame(height: coverHeight)
    }

    private var titleText: some View {
        Text(book.title)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.primary)
            .lineLimit(2)
            .multilineTextAlignment(isMirrored ? .trailing : .leading)
            .frame(maxWidth: .infinity, alignment: isMirrored ? .trailing : .leading)
    }

    private var authorText: some View {
        Text(book.author.isEmpty ? "佚名" : book.author)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: isMirrored ? .trailing : .leading)
    }

    @ViewBuilder
    private var ratingView: some View {
        let safeRating = book.rating
        if safeRating > 0 {
            HStack(spacing: 4) {
                if isMirrored {
                    ratingText(for: safeRating)
                    stars(for: safeRating)
                } else {
                    stars(for: safeRating)
                    ratingText(for: safeRating)
                }
            }
            .frame(maxWidth: .infinity, alignment: isMirrored ? .trailing : .leading)
        }
    }

    private func stars(for rating: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(1 ... 7, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(index <= rating ? .yellow : Color.secondary.opacity(0.2))
            }
        }
    }

    private func ratingText(for rating: Int) -> some View {
        HStack(spacing: 4) {
            Text(rating < AppConstants.ratingPoeticTexts.count ? AppConstants.ratingPoeticTexts[rating] : "")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.orange)
            if rating >= 5 {
                Image(systemName: "crown.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }
        }
    }

    @ViewBuilder
    private var tagView: some View {
        let displayTags = Array(book.tags.prefix(3))
        if !displayTags.isEmpty {
            HStack(spacing: 6) {
                ForEach(isMirrored ? displayTags.reversed() : displayTags, id: \.self) { tag in
                    AppCapsuleLabel(
                        text: tag,
                        tint: .indigo,
                        fontSize: 9,
                        horizontalPadding: 8,
                        verticalPadding: 3
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: isMirrored ? .trailing : .leading)
        }
    }
}

struct YearlyTimelineJourneyTicket: View {
    let book: Book
    var isMirrored: Bool = false

    var body: some View {
        let days = calculateDays(start: book.startDate, end: book.finishDate)

        let startView = dateBlock(title: "始于", date: book.startDate)
        let endView = dateBlock(title: "终于", date: book.finishDate)

        HStack(spacing: 0) {
            if isMirrored {
                endView
                centerLine(days: days, pointsLeft: true)
                startView
            } else {
                startView
                centerLine(days: days, pointsLeft: false)
                endView
            }
        }
    }

    private func dateBlock(title: String, date: Date?) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary.opacity(0.6))
            Text(formatShortDate(date))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(width: 40)
    }

    private func centerLine(days: Int, pointsLeft: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                if pointsLeft {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.teal)
                    Rectangle().fill(Color.teal.opacity(0.4)).frame(height: 1)
                    Circle().fill(Color.teal).frame(width: 4, height: 4)
                } else {
                    Circle().fill(Color.teal).frame(width: 4, height: 4)
                    Rectangle().fill(Color.teal.opacity(0.4)).frame(height: 1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.teal)
                }
            }

            AppCapsuleLabel(
                text: "历时 \(days) 天",
                tint: .teal,
                fontSize: 9,
                horizontalPadding: 10,
                verticalPadding: 3
            )
        }
        .padding(.horizontal, 8)
    }

    private func formatShortDate(_ date: Date?) -> String {
        guard let date else { return "未知" }
        return AppFormatters.dotShortDateFormatter.string(from: date)
    }

    private func calculateDays(start: Date?, end: Date?) -> Int {
        guard let start, let end else { return 1 }
        let calendar = Calendar.current
        let diff = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: end)
        ).day ?? 0
        return max(1, diff + 1)
    }
}
#endif
