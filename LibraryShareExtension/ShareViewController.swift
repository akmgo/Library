import Cocoa
import SwiftData
import UniformTypeIdentifiers

class ShareViewController: NSViewController {

    private lazy var statusLabel: NSTextField = {
        let label = NSTextField(labelWithString: "正在导入 MyLibrary...")
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isEditable = false
        label.isSelectable = false
        label.backgroundColor = .clear
        label.isBordered = false
        return label
    }()

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 120))
        self.view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        processSharedText()
    }

    private func processSharedText() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            self.completeAndDismiss(success: false, message: "获取扩展上下文失败")
            return
        }

        // 拦截网第一层：检查 Apple Books 是否直接把内容塞进了富文本属性里
        if let directText = extensionItem.attributedContentText?.string, !directText.isEmpty {
            DispatchQueue.main.async { self.importToSwiftData(text: directText) }
            return
        }

        // 拦截网第二层：检查是否有附件
        guard let attachments = extensionItem.attachments, !attachments.isEmpty else {
            self.completeAndDismiss(success: false, message: "未获取到有效的分享内容")
            return
        }

        let itemProvider = attachments[0]
        let textType = UTType.text.identifier
        
        if itemProvider.hasItemConformingToTypeIdentifier(textType) {
            itemProvider.loadItem(forTypeIdentifier: textType, options: nil) { [weak self] (item, error) in
                guard let self = self else { return }
                
                var sharedText = ""
                
                // 适配各种可能的数据载体
                if let text = item as? String {
                    sharedText = text
                } else if let url = item as? URL, let text = try? String(contentsOf: url, encoding: .utf8) {
                    sharedText = text
                } else if let attrText = item as? NSAttributedString {
                    sharedText = attrText.string
                } else if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                    sharedText = text
                }
                
                DispatchQueue.main.async {
                    if sharedText.isEmpty {
                        self.completeAndDismiss(success: false, message: "未能提取到文本内容")
                    } else {
                        self.importToSwiftData(text: sharedText)
                    }
                }
            }
        } else {
            completeAndDismiss(success: false, message: "仅支持文本格式的导入")
        }
    }

    // MARK: - SwiftData 写入逻辑
    private func importToSwiftData(text: String) {
        do {
            let container = SharedDatabase.shared.container
            let modelContext = ModelContext(container)
            
            // 调用 Apple Books 解析引擎
            let result = try AppleBooksParser.parse(text: text, context: modelContext)
            
            self.completeAndDismiss(success: true, message: "成功导入: 《\(result.bookTitle)》")
            
        } catch {
            self.completeAndDismiss(success: false, message: "解析失败: \(error.localizedDescription)")
        }
    }

    private func completeAndDismiss(success: Bool, message: String) {
        DispatchQueue.main.async {
            self.statusLabel.stringValue = message
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if success {
                    self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                } else {
                    let err = NSError(domain: "ShareError", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
                    self.extensionContext?.cancelRequest(withError: err)
                }
            }
        }
    }
}
