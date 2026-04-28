#if os(macOS)
import AppKit
import SwiftUI

// MARK: - ✨ 大一统智慧卡片组件

struct SnippetCardView: View {
    let snippet: InspirationSnippet
    let isMasonry: Bool
    
    let isBatchEditMode: Bool
    @Binding var selectedSnippetsForBatch: Set<String>
    
    let onDelete: (InspirationSnippet) -> Void
    let onEdit: (InspirationSnippet) -> Void
    let onLocate: (InspirationSnippet) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        let isSelected = selectedSnippetsForBatch.contains(snippet.id)
        
        VStack(alignment: .leading, spacing: 14) {
            // 1. 顶部 Header
            HStack(alignment: .center, spacing: 8) {
                if isBatchEditMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: isMasonry ? 20 : 16))
                        .foregroundColor(isSelected ? .blue : .secondary.opacity(0.3))
                        .transition(.scale.combined(with: .opacity))
                }
                
                Image(systemName: snippet.isNote ? "quote.opening" : "text.quote")
                    .font(.system(size: isMasonry ? 20 : 16))
                    .foregroundColor((snippet.isNote ? Color.orange : Color.indigo).opacity(0.8))
                
                Spacer()
                
                if !isMasonry {
                    Text(snippet.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.trailing, 4)
                }
                
                Text(snippet.isNote ? "思考" : "摘录")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(snippet.isNote ? .orange : .indigo)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((snippet.isNote ? Color.orange : Color.indigo).opacity(0.1))
                    .clipShape(Capsule())
            }
            
            // 2. 核心文本内容
            Text(LocalizedStringKey(snippet.content))
                .font(.system(size: 14, weight: .medium, design: .serif))
                .lineSpacing(6)
                .foregroundColor(.primary.opacity(0.9))
                .lineLimit(isMasonry ? 12 : nil)
            
            // 3. 极简底部溯源区
            if isMasonry {
                Divider().opacity(0.5).padding(.vertical, 2)
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("《\(snippet.bookTitle)》")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary).lineLimit(1)
                        Text(snippet.date.formatted(date: .numeric, time: .omitted))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !isBatchEditMode {
                        threeDotsMenu()
                    }
                }
            } else {
                if !isBatchEditMode {
                    HStack {
                        Spacer()
                        threeDotsMenu()
                    }
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
        .overlay(RoundedRectangle(cornerRadius: isMasonry ? 16 : 12).stroke(isSelected ? Color.blue : Color.primary.opacity(isHovered ? 0.1 : 0.05), lineWidth: isSelected ? 2 : 1))
        .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.02), radius: isHovered ? 12 : 4, y: isHovered ? 6 : 2)
        .onTapGesture {
            if isBatchEditMode {
                if isSelected { selectedSnippetsForBatch.remove(snippet.id) }
                else { selectedSnippetsForBatch.insert(snippet.id) }
            } else {
                onLocate(snippet)
            }
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
                let textToCopy = "\"\(snippet.content)\"\n—— 《\(snippet.bookTitle)》"
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(textToCopy, forType: .string)
            } label: { Label("一键拷贝", systemImage: "doc.on.doc") }
            
            Button {
                onEdit(snippet)
            } label: { Label("编辑摘录", systemImage: "pencil") }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete(snippet)
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
