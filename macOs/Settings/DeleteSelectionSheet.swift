#if os(macOS)
import SwiftUI
import SwiftData

struct DeleteSelectionSheet: View {
    var allBooks: [Book]
    @Binding var selectedBookIDs: Set<String>
    var onCancel: () -> Void
    var onConfirm: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Text("选择要清理的数据")
                    .font(.system(size: 16, weight: .bold))
                Text("勾选的书籍及其关联的所有笔记、摘录将被彻底删除。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
            
            // 极致性能的 ScrollView + LazyVStack
            if allBooks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("当前书库没有任何数据")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(allBooks) { book in
                            let bookId = book.id ?? ""
                            let isSelected = selectedBookIDs.contains(bookId)
                            
                            HStack(spacing: 10) {
                                Toggle("", isOn: Binding(
                                    get: { isSelected },
                                    set: { newValue in
                                        if newValue { selectedBookIDs.insert(bookId) }
                                        else { selectedBookIDs.remove(bookId) }
                                    }
                                ))
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                
                                Text(book.title ?? "未知书籍")
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle()) // 整行点击热区
                            .onTapGesture {
                                if isSelected { selectedBookIDs.remove(bookId) }
                                else { selectedBookIDs.insert(bookId) }
                            }
                            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color(NSColor.controlBackgroundColor))
            }
            
            Divider()
            
            // Footer Actions
            HStack {
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(role: .destructive, action: onConfirm) {
                    Text("永久删除 (\(selectedBookIDs.count))")
                        .bold()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(selectedBookIDs.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 400, height: 450)
    }
}
#endif
