#if os(macOS)
import AppKit
import SwiftUI

// MARK: - ✨ 大一统智慧卡片组件

struct ExcerptWallCardView: View {
    let excerpt: ExcerptListItem
    let isMasonry: Bool
    
    let onDelete: (ExcerptListItem) -> Void
    let onEdit: (ExcerptListItem) -> Void
    let onLocate: (ExcerptListItem) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. 顶部 Header
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: excerpt.isNote ? "quote.opening" : "text.quote")
                    .font(.system(size: isMasonry ? 20 : 16))
                    .foregroundColor((excerpt.isNote ? Color.orange : Color.indigo).opacity(0.8))
                
                Spacer()
                
                if !isMasonry {
                    Text(excerpt.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.trailing, 4)
                }
                
                Text(excerpt.isNote ? "思考" : "摘录")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(excerpt.isNote ? .orange : .indigo)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((excerpt.isNote ? Color.orange : Color.indigo).opacity(0.1))
                    .clipShape(Capsule())
            }
            
            // 2. 核心文本内容
            Text(LocalizedStringKey(excerpt.content))
                .font(.system(size: 14, weight: .medium, design: .serif))
                .lineSpacing(6)
                .foregroundColor(.primary.opacity(0.9))
                .lineLimit(isMasonry ? 12 : nil)
            
            // 3. 极简底部溯源区
            if isMasonry {
                Divider().opacity(0.5).padding(.vertical, 2)
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("《\(excerpt.bookTitle)》")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary).lineLimit(1)
                        Text(excerpt.date.formatted(date: .numeric, time: .omitted))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    threeDotsMenu()
                }
            } else {
                HStack {
                    Spacer()
                    threeDotsMenu()
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
        .cornerRadius(isMasonry ? 16 : 12)
        .overlay(RoundedRectangle(cornerRadius: isMasonry ? 16 : 12).stroke(Color.primary.opacity(isHovered ? 0.1 : 0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.02), radius: isHovered ? 12 : 4, y: isHovered ? 6 : 2)
        .onTapGesture {
            onLocate(excerpt)
        }
        .onHover { h in
            withAnimation(.appSnappy) { isHovered = h }
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
    
    // MARK: - 独立菜单视图
    private func threeDotsMenu() -> some View {
        Menu {
            Button {
                let textToCopy = "\"\(excerpt.content)\"\n—— 《\(excerpt.bookTitle)》"
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(textToCopy, forType: .string)
            } label: { Label("一键拷贝", systemImage: "doc.on.doc") }
            
            Button {
                onEdit(excerpt)
            } label: { Label("编辑摘录", systemImage: "pencil") }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete(excerpt)
            } label: { Label("删除片段", systemImage: "trash") }
            
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.8), in: Circle())
                .shadow(radius: 2)
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .opacity(isHovered ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}
#endif
