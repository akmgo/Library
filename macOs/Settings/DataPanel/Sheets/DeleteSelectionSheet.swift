#if os(macOS)
import SwiftUI
import SwiftData

// MARK: - ✨ 选择清理数据弹窗

/// 在危险操作区呼出的选择性清理抽屉视图。
///
/// **交互设计：**
/// 提供一个支持复选框的多选列表容器。为了保证在大量书籍数据时的绝对流畅，
/// 内部使用了 `ScrollView` 结合 `LazyVStack` 进行长列表复用渲染。
struct DeleteSelectionSheet: View {
    /// 传入的所有供勾选操作的书籍源数据
    var allBooks: [Book]
    
    /// 双向绑定当前选中计划被删除的书籍 ID 集合
    @Binding var selectedBookIDs: Set<String>
    
    /// 用户点击取消时的退出回调
    var onCancel: () -> Void
    /// 用户确认永久删除时的执行回调
    var onConfirm: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header 标题引导区
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
                            .contentShape(Rectangle()) // 使整行处于可点击热区，极大地增强了 macOS 的鼠标交互体验
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
            
            // Footer Actions 防呆确认区
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
