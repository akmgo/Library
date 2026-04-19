import SwiftUI
import SwiftData

#if os(iOS)
struct MobileAddExcerptSheet: View {
    let book: Book
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var content: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("输入书中打动你的金句...", text: $content, axis: .vertical)
                        .lineLimit(8...15)
                        .focused($isFocused)
                        .padding(.vertical, 8)
                        // 摘录通常更有文学感，所以我们用衬线字体
                        .font(.system(size: 16, weight: .regular, design: .serif))
                } footer: {
                    Text("摘录将展示在首页的“思想共鸣”卡片中。")
                }
            }
            .navigationTitle("加摘录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.secondary) // 原生次级颜色
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    let isEmpty = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    Button("保存") { saveExcerpt() }
                        .fontWeight(.bold)
                        .disabled(isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isFocused = true }
            }
        }
    }
    
    private func saveExcerpt() {
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanContent.isEmpty {
            let excerpt = Excerpt(content: cleanContent)
            if book.excerpts == nil { book.excerpts = [] }
            book.excerpts?.append(excerpt)
            try? modelContext.save()
            dismiss()
        }
    }
}
#endif
