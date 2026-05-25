#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 📚 想读列车画廊 (纯粹渲染版)

struct MobileQueueCarouselCard: View {
    let displayBooks: [Book]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        GroupBox {
            if displayBooks.isEmpty {
                VStack {
                    Text("暂无想读计划")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(displayBooks) { book in
                            NavigationLink(destination: MobileBookDetailView(book: book)) {
                                BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                                    .frame(width: 84, height: 126)
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover))
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded {
                                if book.status == .planned {
                                    try? ReadingDataService.shared.markBookStartedFromQueue(book, context: modelContext)
                                }
                            })
                        }
                    }
                }
                .padding(.top, AppSpacing.xs)
            }
        } label: {
            HStack {
                Text("想读列车")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "sparkles.rectangle.stack")
                    .foregroundColor(AppColors.readingAmber)
            }
        }
    }
}

#if DEBUG
private struct PreviewQueueCard: View {
    var body: some View {
        PreviewWithBooks(specs: [
            ("苏菲的世界", "Jostein Gaarder", .planned, .page, 544, 0),
            ("人类简史", "Yuval Noah Harari", .planned, .page, 440, 0),
            ("枪炮、病菌与钢铁", "Jared Diamond", .planned, .page, 496, 0),
            ("思考，快与慢", "Daniel Kahneman", .planned, .page, 424, 0),
        ]) { books in
            MobileQueueCarouselCard(displayBooks: books)
                .padding()
                .background(Color(UIColor.systemGroupedBackground))
        }
    }
}

#Preview("想读列车卡") {
    PreviewQueueCard()
        .modelContainer(previewModelContainer)
}
#endif


#endif
