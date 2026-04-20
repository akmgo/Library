#if os(macOS)
import SwiftUI

// MARK: - 子组件：纯净扁平版宽卡片

/// 专用于 “书籍分类” 模式下渲染的长条形扁平化知识卡片。
///
/// 采用极宽的响应式排版（由于左侧已经展示了书籍封面，此处隐去了内部封面）。
/// 提供鼠标悬浮 (Hover) 时的光影加深及物理弹起反馈。
struct GroupedSnippetCardView: View {
    let snippet: InspirationSnippet
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Image(systemName: snippet.isNote ? "quote.opening" : "text.quote")
                    .font(.system(size: 16))
                    .foregroundColor((snippet.isNote ? Color.orange : Color.indigo).opacity(0.8))
                
                Spacer()
                
                Text(snippet.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.trailing, 4)
                
                Text(snippet.isNote ? "思考" : "摘录")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(snippet.isNote ? .orange : .indigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((snippet.isNote ? Color.orange : Color.indigo).opacity(0.1))
                    .clipShape(Capsule())
            }
            Text(LocalizedStringKey(snippet.content))
                .font(.system(size: 14, weight: .medium, design: .serif))
                .lineSpacing(6)
                .foregroundColor(.primary.opacity(0.9))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .controlBackgroundColor)
                .opacity(isHovered ? 0.9 : 0.6)
                .background(.ultraThinMaterial)
        )
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(isHovered ? 0.1 : 0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(isHovered ? 0.06 : 0.02), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        .onHover { h in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isHovered = h }
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - 子组件：瀑布流版微缩卡片

/// 专用于 “随机漫游” 瀑布流模式下渲染的独立碎句卡片。
///
/// 它被设计成高度紧凑且包含完整数据回溯链（在卡片底部附带微缩实体书封面及书籍源标题），
/// 方便用户在随机浏览时能够随时追踪某条智慧火花的来源出处。
struct MasonrySnippetCardView: View {
    let snippet: InspirationSnippet
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Image(systemName: snippet.isNote ? "quote.opening" : "text.quote")
                    .font(.system(size: 20))
                    .foregroundColor((snippet.isNote ? Color.orange : Color.indigo).opacity(0.8))
                
                Spacer()
                
                Text(snippet.isNote ? "思考" : "摘录")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(snippet.isNote ? .orange : .indigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((snippet.isNote ? Color.orange : Color.indigo).opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Text(LocalizedStringKey(snippet.content))
                .font(.system(size: 14, weight: .medium, design: .serif))
                .lineSpacing(6)
                .foregroundColor(.primary.opacity(0.9))
                .lineLimit(12)
            
            Divider().opacity(0.5)
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("《\(snippet.bookTitle)》")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(snippet.date.formatted(date: .numeric, time: .omitted))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let coverData = snippet.coverData {
                    LocalCoverView(coverData: coverData, fallbackTitle: snippet.bookTitle)
                        .frame(width: 32, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .shadow(color: Color.black.opacity(0.1), radius: 3, y: 1)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .controlBackgroundColor)
                .opacity(isHovered ? 0.9 : 0.6)
                .background(.ultraThinMaterial)
        )
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(isHovered ? 0.1 : 0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 12 : 8, y: isHovered ? 6 : 4)
        .onHover { h in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isHovered = h }
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
#endif
