#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

// MARK: - 枚举与模式

enum ContentSheetMode {
    case excerpt
    case note
}

// MARK: - ✨ 内容增改通用弹窗

struct ContentEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    
    let book: Book?
    let mode: ContentSheetMode
    
    // ✨ 核心修复：接收全新的统一大实体 Excerpt
    var itemToEdit: Excerpt? = nil
    
    @State private var contentText: String = ""
    
    var body: some View {
        let isEdit = itemToEdit != nil
        
        VStack(spacing: 0) {
            // ================= 1. 原生顶部标题 =================
            HStack(spacing: 12) {
                Image(systemName: mode == .excerpt ? (isEdit ? "quote.closing" : "quote.opening") : "pencil.line")
                    .font(.system(size: 20))
                    .foregroundColor(mode == .excerpt ? .blue : .purple)
                
                Text(isEdit ? (mode == .excerpt ? "编辑摘录" : "编辑笔记") : (mode == .excerpt ? "新增摘录" : "记录灵感"))
                    .font(.system(size: 18, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider().opacity(0.5)
            
            // ================= 2. 核心文本编辑区 =================
            ZStack(alignment: .topLeading) {
                Color.clear
                
                if mode == .excerpt {
                    TextEditor(text: $contentText)
                        .font(.system(size: 15))
                        .scrollContentBackground(.hidden)
                        .padding(16)
                } else {
                    MarkdownEditor(text: $contentText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                }
                
                if contentText.isEmpty {
                    Text(mode == .excerpt ? "输入那些值得被铭记的内容..." : "敲击 # 输入大标题\n敲击 - 或 1. 记录要点\n\n按下回车即可自然换行...")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary.opacity(0.6))
                        .lineSpacing(6)
                        .padding(.top, mode == .excerpt ? 16 : 24)
                        .padding(.leading, mode == .excerpt ? 20 : 32)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider().opacity(0.5)
            
            // ================= 3. 底部操作区 =================
            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 6))
                
                let isContentValid = !contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let hasChanges = isEdit ? (contentText != itemToEdit?.content) : true
                let canSave = isContentValid && hasChanges
                
                Button(isEdit ? "保存修改" : (mode == .excerpt ? "保存摘录" : "保存笔记")) { saveContent() }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .glassEffect(canSave ? .regular.tint(.blue).interactive() : .clear.interactive(), in: .rect(cornerRadius: 6))
                    .opacity(canSave ? 1.0 : 0.4)
            }
            .padding(16)
        }
        .frame(width: 540, height: 420)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .background(WindowTransparentEffect())
        .onAppear {
            if let item = itemToEdit {
                contentText = item.content
            }
        }
    }
    
    // MARK: - 存储逻辑
    
    private func saveContent() {
        guard !contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        if let item = itemToEdit {
            // ✨ 编辑模式：直接更新单体字段，逻辑极致简单
            item.content = contentText
            try? modelContext.save()
        } else if let targetBook = book {
            // ✨ 新增模式：注入明确的 Type
            try? ReadingDataService.shared.insertExcerpt(
                content: contentText,
                category: mode == .excerpt ? .bookExcerpt : .note,
                book: targetBook,
                context: modelContext
            )
        }
        
        isPresented = false
    }
}

// MARK: - ⚙️ 极简纯净原生 Markdown 引擎
struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 24, height: 24)
        textView.insertionPointColor = NSColor.textColor
        
        scrollView.documentView = textView
        context.coordinator.applyStyling(to: textView)
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            context.coordinator.applyStyling(to: textView)
        }
        textView.insertionPointColor = NSColor.textColor
        context.coordinator.applyStyling(to: textView)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        init(_ parent: MarkdownEditor) { self.parent = parent }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            applyStyling(to: textView)
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            applyStyling(to: textView)
        }
        
        func applyStyling(to textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            let string = textStorage.string
            let fullRange = NSRange(location: 0, length: textStorage.length)
            
            let selectedRange = textView.selectedRange()
            let currentLineRange = (string as NSString).lineRange(for: selectedRange)
            
            let baseFont = NSFont.systemFont(ofSize: 15, weight: .regular)
            let baseColor = NSColor.textColor
            let syntaxColor = NSColor.secondaryLabelColor
            let listColor = NSColor.controlAccentColor
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 8
            
            textStorage.beginEditing()
            textStorage.setAttributes([.font: baseFont, .foregroundColor: baseColor, .paragraphStyle: paragraphStyle], range: fullRange)
            
            let headingRegex = try! NSRegularExpression(pattern: "^(#{1,3})(\\s+)(.*)$", options: .anchorsMatchLines)
            headingRegex.enumerateMatches(in: string, range: fullRange) { match, _, _ in
                guard let match = match else { return }
                let hashRange = match.range(at: 1); let spaceRange = match.range(at: 2); let level = hashRange.length
                let font: NSFont = level == 1 ? .systemFont(ofSize: 24, weight: .bold) : level == 2 ? .systemFont(ofSize: 20, weight: .bold) : .systemFont(ofSize: 18, weight: .semibold)
                
                textStorage.addAttribute(.font, value: font, range: match.range)
                let isCurrentLine = NSIntersectionRange(match.range, currentLineRange).length > 0
                if isCurrentLine {
                    textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: hashRange)
                } else {
                    textStorage.addAttribute(.foregroundColor, value: NSColor.clear, range: hashRange)
                    textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: 0.01), range: hashRange)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.clear, range: spaceRange)
                    textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: 0.01), range: spaceRange)
                }
            }
            
            let listRegex = try! NSRegularExpression(pattern: "^([-*])(\\s+)(.*)$", options: .anchorsMatchLines)
            listRegex.enumerateMatches(in: string, range: fullRange) { match, _, _ in
                guard let match = match else { return }
                let bulletRange = match.range(at: 1)
                let listStyle = NSMutableParagraphStyle(); listStyle.headIndent = 24; listStyle.firstLineHeadIndent = 0; listStyle.lineSpacing = 8
                textStorage.addAttribute(.paragraphStyle, value: listStyle, range: match.range)
                textStorage.addAttribute(.foregroundColor, value: listColor, range: bulletRange)
                textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: 18, weight: .black), range: bulletRange)
            }
            
            let numRegex = try! NSRegularExpression(pattern: "^(\\d+\\.)(\\s+)(.*)$", options: .anchorsMatchLines)
            numRegex.enumerateMatches(in: string, range: fullRange) { match, _, _ in
                guard let match = match else { return }
                let numRange = match.range(at: 1)
                let listStyle = NSMutableParagraphStyle(); listStyle.headIndent = 24; listStyle.firstLineHeadIndent = 0; listStyle.lineSpacing = 8
                textStorage.addAttribute(.paragraphStyle, value: listStyle, range: match.range)
                textStorage.addAttribute(.foregroundColor, value: listColor, range: numRange)
                textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: 15, weight: .bold), range: numRange)
            }
            textStorage.endEditing()
        }
    }
}

#Preview("通用内容增改弹窗") {
    ContentEditorSheet(isPresented: .constant(true), book: nil, mode: .excerpt)
        .padding(40)
        .background(LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom))
}
#endif
