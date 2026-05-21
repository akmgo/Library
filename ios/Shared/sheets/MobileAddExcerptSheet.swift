#if os(iOS)
import SwiftUI
import SwiftData

// MARK: - 📝 摘录录入表单

/// 专门用于记录书中原文摘录的轻量级表单。
///
/// **交互特性：**
/// 采用了 `.serif` 衬线体以渲染文学感。
/// 利用 `@FocusState` 在视图呼出时自动拉起键盘，确保用户实现“即点即记，记完即走”的极速体验。
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
                        // 摘录通常更有文学感，所以我们强制使用衬线字体
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
                // 延迟极短的时间以确保视图树渲染完毕后自动呼出键盘
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isFocused = true }
            }
        }
    }
    
    private func saveExcerpt() {
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanContent.isEmpty {
            try? ReadingDataService.shared.insertExcerpt(
                content: cleanContent,
                category: .bookExcerpt,
                book: book,
                context: modelContext
            )
            dismiss()
        }
    }
}
#endif
