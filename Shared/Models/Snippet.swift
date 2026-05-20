#if os(macOS) || os(iOS)
import Foundation
import SwiftData

@Model
final class Snippet {
    var id: String = UUID().uuidString
    var content: String = ""
    var title: String = ""
    var author: String = "佚名"
    var dynasty: String = ""
    var annotation: String = ""
    var category: SnippetCategory = SnippetCategory.web
    var addedDate: Date = Date()

    init(title: String = "无题", content: String, author: String = "佚名", dynasty: String = "", annotation: String = "", category: SnippetCategory = .web) {
        self.title = title
        self.content = content
        self.author = author
        self.dynasty = dynasty
        self.annotation = annotation
        self.category = category
        self.addedDate = Date()
    }
}
#endif
