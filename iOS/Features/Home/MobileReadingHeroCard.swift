#if os(iOS)
import SwiftUI
import SwiftData

// MARK: - 在读焦点卡 (含进度 + 其它在读切换)

struct MobileReadingHeroCard: View {
    let book: Book
    let secondaryBooks: [Book]
    let onTapDetail: () -> Void
    let onSelectSecondaryBook: (Book) -> Void

    private let coverWidth: CGFloat = 90
    private let coverHeight: CGFloat = 135

    private var progressPercentage: Int {
        Int(book.progressRatio * 100)
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack {
                    Text("在读焦点")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "book.closed.fill")
                        .foregroundColor(AppColors.readingAmber)
                }
                // 上半部分：封面 + 元数据
                HStack(alignment: .center, spacing: 18) {
                    Button(action: onTapDetail) {
                        BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                            .frame(width: coverWidth, height: coverHeight)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
                            .shadow(color: Color.black.opacity(0.15), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(book.title)
                                .font(.system(size: 22, weight: .heavy, design: .serif))
                                .foregroundColor(.primary)
                                .lineLimit(2)

                            Text(book.author)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 12)

                        // 进度区域
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(progressDetailText)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                                
                                Spacer()

                                Text("\(progressPercentage)%")
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .foregroundColor(AppColors.readingAmber)
                                    .contentTransition(.numericText())
                            }

                            ProgressBarView(progress: book.progressRatio, tint: AppColors.readingAmber, height: 6)
                        }
                    }
                    .frame(height: coverHeight, alignment: .center)
                }
                .padding(.vertical, 2)

                // 下半部分：其它在读横向滚动条
                if !secondaryBooks.isEmpty {
                    Divider().opacity(0.3)

                    secondaryStrip
                }
            }
        }
    }
    
    private var progressDetailText: String {
        guard book.totalAmount > 0 else {
            switch book.progressUnit {
            case .page:
                return "页数未设置"
            case .chapter:
                return "章节数未设置"
            case .percent:
                return "当前进度"
            }
        }

        switch book.progressUnit {
        case .page:
            return "\(Int(book.currentAmount)) / \(Int(book.totalAmount)) 页"
        case .chapter:
            return "\(Int(book.currentAmount)) / \(Int(book.totalAmount)) 章"
        case .percent:
            return "当前进度"
        }
    }

    // MARK: - 其它在读横向滚动条

    private var secondaryStrip: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("其它在读")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(secondaryBooks) { candidate in
                        Button {
                            onSelectSecondaryBook(candidate)
                        } label: {
                            HStack(spacing: 8) {
                                BookCoverView(
                                    coverID: candidate.id,
                                    coverData: candidate.coverData,
                                    fallbackTitle: candidate.title
                                )
                                .frame(width: 34, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .shadow(color: Color.black.opacity(0.08), radius: 3, y: 2)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(candidate.title)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Spacer()

                                    ProgressBarView(progress: candidate.progressRatio, tint: AppColors.readingAmber, height: 5, animated: false)
                                        .frame(width: 60)
                                }
                                .frame(height: 40)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .appInnerBlockStyle(cornerRadius: 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - 空状态视图

struct MobileEmptyReadingCard: View {
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack {
                    Text("在读焦点")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "book.closed.fill")
                        .foregroundColor(AppColors.readingAmber)
                }
                HStack(alignment: .center, spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous)
                            .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .background(Color.secondary.opacity(0.02))
                        Image(systemName: "book.closed")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                    .frame(width: 90, height: 135)
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text("虚位以待")
                                .font(.system(size: 22, weight: .heavy, design: .serif))
                                .foregroundColor(.primary.opacity(0.5))
                            Text("寻找下一段旅程")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

#if DEBUG
private struct PreviewHeroCard: View {
    var body: some View {
        PreviewWithBooks(specs: [
            ("三体", "刘慈欣", .reading, .page, 320, 156),
            ("活着", "余华", .reading, .page, 192, 80),
            ("1984", "George Orwell", .reading, .percent, 100, 62),
        ]) { books in
            MobileReadingHeroCard(
                book: books[0],
                secondaryBooks: Array(books.dropFirst()),
                onTapDetail: {},
                onSelectSecondaryBook: { _ in }
            )
            .padding()
            .background(AppColors.primaryBackground(for: .light))
        }
    }
}

#Preview("在读焦点卡 - 有进度") {
    PreviewHeroCard()
        .modelContainer(previewModelContainer)
}

#Preview("在读焦点卡 - 空状态") {
    MobileEmptyReadingCard()
        .padding()
        .background(AppColors.primaryBackground(for: .light))
}
#endif


#endif
