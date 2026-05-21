#if os(macOS)
import SwiftData
import SwiftUI

// MARK: - 🎨 在读焦点视图

struct ReadingHero: View {
    @Bindable var book: Book
    
    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                .frame(width: 170, height: 245)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 12, y: 8)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 8) {
                Text(book.title)
                    .font(.system(size: 36, weight: .heavy, design: .serif))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(book.author)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(height: 245)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 🎨 空状态视图

struct EmptyReadingHero: View {
    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                    .frame(width: 170, height: 245)
                    .background(Color.secondary.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                VStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("暂无在读")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            
            VStack(alignment: .leading, spacing: 0) {
                
                Text("虚位以待")
                    .font(.system(size: 36, weight: .heavy, design: .serif))
                    .foregroundColor(.primary.opacity(0.4))
                    .lineLimit(2)
                
                Text("去书库中挑选一本开启新旅程吧")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.5))
                    .lineLimit(1)
                    .padding(.top, 4)
            }
            .frame(height: 245)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
}
#endif
