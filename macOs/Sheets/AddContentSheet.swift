#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

// MARK: - 枚举与模式

/// 定义应用内“内容弹窗”的业务模式。
///
/// 这是一个共享视图的路由开关，用于区分当前呼出的是摘录（使用原生 `TextEditor`）还是思考笔记（使用 `MarkdownEditor`）。
enum ContentSheetMode {
    case excerpt
    case note
}

// MARK: - ✨ 内容增添弹窗

/// 统一的文本内容增添弹窗 (Add Content Sheet)。
///
/// **交互特性：**
/// 该视图被设计为模态框 (`.sheet`)。
/// 提供了极简的无边框输入体验，包含顶部状态指示器和底部的系统原生按钮（支持键盘快捷键绑定，按 `Enter` 保存，按 `Esc` 取消）。
struct AddContentSheet: View {
    @Environment(\.modelContext) private var modelContext
    
    @Binding var isPresented: Bool
    
    /// 承载本次新增内容的宿主书籍。
    let book: Book
    let mode: ContentSheetMode
    
    @State private var contentText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // ================= 1. 原生顶部标题 =================
            HStack(spacing: 12) {
                Image(systemName: mode == .excerpt ? "quote.opening" : "pencil.line")
                    .font(.system(size: 20))
                    .foregroundColor(mode == .excerpt ? .blue : .purple)
                
                Text(mode == .excerpt ? "新增摘录" : "记录灵感")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
            
            // ================= 2. 核心文本编辑区 =================
            ZStack(alignment: .topLeading) {
                // 原生文本背景色
                Color(nsColor: .textBackgroundColor).ignoresSafeArea()
                
                if mode == .excerpt {
                    // 摘录模式：纯文本
                    TextEditor(text: $contentText)
                        .font(.system(size: 15))
                        .scrollContentBackground(.hidden)
                        .padding(16)
                } else {
                    // 笔记模式：Markdown 实时渲染
                    MarkdownEditor(text: $contentText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                }
                
                // 占位符层
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
            
            Divider()
            
            // ================= 3. 底部操作区 =================
            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                
                let canSave = !contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                
                Button(mode == .excerpt ? "保存摘录" : "保存笔记") { saveContent() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 540, height: 420)
    }
    
    // MARK: - 存储逻辑
    
    /// 执行持久化落库动作。
    ///
    /// 将当前的输入文本包装为 `Excerpt` 或 `Note` 实体，强行插入（关联）到 `book` 对象中，
    /// 并触发全局数据库的 `save()`，最后降下弹窗。
    private func saveContent() {
        guard !contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        if mode == .excerpt {
            let newExcerpt = Excerpt(content: contentText)
            if book.excerpts == nil { book.excerpts = [] }
            book.excerpts?.append(newExcerpt)
        } else {
            let newNote = Note(content: contentText)
            if book.notes == nil { book.notes = [] }
            book.notes?.append(newNote)
        }
        
        try? modelContext.save()
        isPresented = false
    }
}

// MARK: - ⚙️ 极简纯净原生 Markdown 引擎

/// 利用 `NSTextView` 封装的 macOS 专属原生 Markdown 实时高亮编辑器。
///
/// **架构特性：**
/// 该引擎抛弃了复杂的第三方库，通过正则表达式 (`NSRegularExpression`) 和 `NSAttributedString`
/// 实现所见即所得的极简语法高亮。
/// - 支持 1~3 级标题（`#`）放大与加粗。
/// - 支持无序列表（`-`, `*`）和有序列表（`1.`）的首行缩进与圆点高亮。
/// - 内部使用原生的 `NSColor.textColor`，从而实现**零代码自适应系统的深浅模式切换**。
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
        // 🍏 交由系统自动管理光标颜色
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
            
            // 🍏 全部换成系统原生的动态颜色
            let baseColor = NSColor.textColor
            let syntaxColor = NSColor.secondaryLabelColor
            let listColor = NSColor.controlAccentColor // 系统的强调色
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 8
            
            textStorage.beginEditing()
            textStorage.setAttributes([.font: baseFont, .foregroundColor: baseColor, .paragraphStyle: paragraphStyle], range: fullRange)
            
            // 处理标题
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
            
            // 处理无序列表
            let listRegex = try! NSRegularExpression(pattern: "^([-*])(\\s+)(.*)$", options: .anchorsMatchLines)
            listRegex.enumerateMatches(in: string, range: fullRange) { match, _, _ in
                guard let match = match else { return }
                let bulletRange = match.range(at: 1)
                let listStyle = NSMutableParagraphStyle(); listStyle.headIndent = 24; listStyle.firstLineHeadIndent = 0; listStyle.lineSpacing = 8
                textStorage.addAttribute(.paragraphStyle, value: listStyle, range: match.range)
                textStorage.addAttribute(.foregroundColor, value: listColor, range: bulletRange)
                textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: 18, weight: .black), range: bulletRange)
            }
            
            // 处理有序列表
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
#endif
