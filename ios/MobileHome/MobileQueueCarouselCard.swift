#if os(iOS)
import SwiftUI

// MARK: - 📚 想读列车画廊 (纯粹渲染版)

struct MobileQueueCarouselCard: View {
    // ✨ 修改命名以匹配 MobileHomeView 传参
    let displayBooks: [Book]
    
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
                    HStack(spacing: 16) {
                        ForEach(displayBooks) { book in
                            NavigationLink(destination: MobileBookDetailView(book: book)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                                        .frame(width: 80, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover))
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                                    
                                    Text(book.title)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(width: 80, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 8)
            }
        } label: {
            HStack {
                Text("想读列车")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "sparkles.rectangle.stack")
                    .foregroundColor(.orange)
            }
        }
    }
}
#endif
