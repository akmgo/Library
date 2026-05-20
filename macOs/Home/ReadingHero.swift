#if os(macOS)
import SwiftData
import SwiftUI

// MARK: - 🎨 在读焦点视图

struct ReadingHero: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var modelContext
    
    var onDetailTap: () -> Void = {} // 暴露详情回调
    @State private var isHoveringCard = false
    
    var body: some View {
        let normalizedProgress = book.progressRatio
        
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .center, spacing: 24) {
                BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                    .frame(width: 170, height: 245)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 12, y: 8)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(book.title)
                        .font(.system(size: 36, weight: .heavy, design: .serif))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(book.author)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .padding(.top, 4)
                    
                    Spacer()
                    
                    // ✨ 对齐 iOS 布局：左侧文字，右侧百分比
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .lastTextBaseline) {
                            Text("阅读进度")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(Int(book.progressRatio * 100))%")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .contentTransition(.numericText())
                        }
                        
                        CustomTrackBar(value: normalizedProgress, color: .blue)
                    }
                }
                .frame(height: 245)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // 悬浮详情按钮
            Button(action: onDetailTap) {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary.opacity(0.8), .secondary.opacity(0.15))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .opacity(isHoveringCard ? 1.0 : 0.0)
            .scaleEffect(isHoveringCard ? 1.0 : 0.8)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHoveringCard)
            .onHover { isHovered in if isHovered { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        }
        .onHover { isHovered in isHoveringCard = isHovered }
    }
}

// 轨道组件保持不变
private struct CustomTrackBar: View {
    let value: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.12))
                Capsule().fill(color).frame(width: max(0, geo.size.width * value))
            }
        }
        .frame(height: 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: value)
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
                
                Spacer()
                
                // ✨ 空状态也要对齐 iOS 布局
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .lastTextBaseline) {
                        Text("当前进度")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Spacer()
                        
                        Text("0%")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                    CustomTrackBar(value: 0, color: .secondary.opacity(0.2))
                }
            }
            .frame(height: 245)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
}
#endif
