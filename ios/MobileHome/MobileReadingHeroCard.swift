#if os(iOS)
import SwiftUI
import SwiftData

// MARK: - 🌟 顶部焦点区域组件 (标志同步版)

struct MobileReadingHeroCard: View {
    let book: Book
    var body: some View {
        let safeTitle = book.title
        let safeAuthor = book.author
        let progress = book.progressRatio
        
        GroupBox {
            HStack(alignment: .top, spacing: 18) {
                // 左侧封面
                BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: safeTitle)
                    .frame(width: 90, height: 135)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 6, y: 3)
                
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(safeTitle)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Text(safeAuthor)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 12)
                    
                    // 底部：进度展示
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .lastTextBaseline) {
                            Text("阅读进度")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .foregroundColor(.blue)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.15))
                                Capsule().fill(Color.blue.gradient)
                                    .frame(width: max(0, geo.size.width * CGFloat(progress)))
                            }
                        }.frame(height: 6)
                    }
                }
            }
            .padding(.vertical, 2)
        } label: {
            HStack {
                Text("在读焦点").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "book.closed.fill").foregroundColor(.blue)
            }
        }
    }
}

// MARK: - 🎨 空状态视图 (标志同步版)

struct MobileEmptyReadingCard: View {
    var body: some View {
        GroupBox {
            HStack(alignment: .center, spacing: 18) {
                // 左侧占位图
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

                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("虚位以待")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary.opacity(0.5))
                        
                        Text("寻找下一段旅程")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // 底部占位进度
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .lastTextBaseline) {
                            Text("当前进度")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.3))
                            Spacer()
                            Text("0%")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundColor(.secondary.opacity(0.2))
                        }
                        Capsule().fill(Color.secondary.opacity(0.08)).frame(height: 6)
                    }
                }
            }
            .padding(.vertical, 2)
        } label: {
            HStack {
                Text("在读焦点").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "book.closed.fill").foregroundColor(.blue)
            }
        }
    }
}
#endif
