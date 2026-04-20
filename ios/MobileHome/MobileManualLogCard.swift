#if os(iOS)
import SwiftUI
import SwiftData

// MARK: - 📝 半宽版：纯视觉打卡组件

/// 移动端主页的手动补录打卡入口卡片。
///
/// **交互特性：**
/// 该卡片采用半宽正方形设计（通常与番茄钟卡片并排），提供一个极简且超大号的触控热区。
/// 点击后将唤起底部的 `MobileManualLogSheet` 弹窗，供用户手动补录昨天的遗漏或快速记录碎片化阅读。
struct MobileManualLogCard: View {
    let defaultBook: Book
    let allBooks: [Book]
    
    @State private var showLogSheet = false
    
    var body: some View {
        GroupBox {
            Button {
                showLogSheet = true
            } label: {
                ZStack {
                    // ✨ 超大号、极简纤细风格的图标，填满整个内容区
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 75, weight: .ultraLight))
                        .foregroundColor(.indigo)
                }
                .frame(height: 100) // ✨ 与左侧计时器高度严格同步
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle()) // 确保整个留白区域都可点击
            }
            .buttonStyle(.plain) // 去除按钮默认按下时的变色干扰
        } label: {
            HStack {
                Text("补录打卡")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.indigo)
            }
        }
        .sheet(isPresented: $showLogSheet) {
            // 呼出独立的补录表单，将当前焦点书籍作为默认选中项传入
            MobileManualLogSheet(defaultBook: defaultBook, allBooks: allBooks)
        }
    }
}
#endif
