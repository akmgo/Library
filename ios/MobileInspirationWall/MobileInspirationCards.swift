#if os(iOS)
import SwiftUI

// MARK: - ✨ 高级数据看板 Header

/// 放置在列表最顶端的总控统计面板。
/// 使用了极具冲击力的衬线字体 (`.serif`) 强调文字的沉淀感。
struct MobileInspirationStatsHeader: View {
    let totalSnippets: Int
    let totalCharacters: Int
    let uniqueBooksCount: Int
    
    var body: some View {
        let formattedKCount = String(format: "%.1f", Double(totalCharacters) / 1000.0)
        
        HStack(spacing: 0) {
            // 数据 1：总字数
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(totalCharacters > 1000 ? formattedKCount : "\(totalCharacters)")
                        .font(.system(size: 28, weight: .heavy, design: .serif))
                        .foregroundColor(.primary)
                    Text(totalCharacters > 1000 ? "k" : "")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.indigo)
                }
                Text("字沉淀").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
                        
            Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 32)
                        
            // 数据 2：书籍广度
            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(uniqueBooksCount)")
                        .font(.system(size: 28, weight: .heavy, design: .serif))
                        .foregroundColor(.primary)
                    Text("本").font(.system(size: 14, weight: .bold)).foregroundColor(.orange)
                }
                Text("知识源泉").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.8).background(.ultraThinMaterial))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - 📚 归档模式：纯净扁平版宽卡片

/// 专用于 “书籍分类” 模式下渲染的长条形扁平化知识卡片。
///
/// 由于外层父级视图已经展示了书籍封面，此处隐去了内部小封面，注重内容的纵向阅读体验。
struct MobileGroupedSnippetCardView: View {
    let snippet: MobileInspirationSnippet
    
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
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((snippet.isNote ? Color.orange : Color.indigo).opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Text(LocalizedStringKey(snippet.content))
                .font(.system(size: 15, weight: .regular, design: .serif))
                .lineSpacing(6)
                .foregroundColor(.primary.opacity(0.9))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 3)
    }
}

// MARK: - 🌊 漫游模式：包含溯源封面的微缩瀑布流卡片

/// 专用于 “随机漫游” 瀑布流模式下渲染的独立碎句卡片。
///
/// 它被设计成高度紧凑且包含完整数据回溯链。卡片底部附带微缩实体书封面及书籍源标题，
/// 方便用户在随机浏览时能够随时追踪某条智慧火花的来源出处。
struct MobileMasonrySnippetCardView: View {
    let snippet: MobileInspirationSnippet
    
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
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((snippet.isNote ? Color.orange : Color.indigo).opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Text(LocalizedStringKey(snippet.content))
                .font(.system(size: 15, weight: .regular, design: .serif))
                .lineSpacing(6)
                .foregroundColor(.primary.opacity(0.9))
                .lineLimit(12) // 截断超长废话，维持瀑布流均衡感
            
            Divider().opacity(0.5)
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("《\(snippet.bookTitle)》")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(snippet.date.formatted(date: .numeric, time: .omitted))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // ✨ 完美移植 macOS 的微缩封面设计
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
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
    }
}
#endif
