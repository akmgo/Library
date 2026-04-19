import SwiftUI

struct NativeWidgetGroupBoxStyle: GroupBoxStyle {
    @Environment(\.colorScheme) var colorScheme
    
    // ✨ 在这里精准控制你的卡片底色调
    private var cardTintColor: Color {
        if colorScheme == .light {
            // 🍎 苹果官方标准：浅色模式下，盖上一层高透明度的“纯白色”。
            // 这层纯白会直接“洗掉”毛玻璃自带的灰色，让它变成一块极其干净、通透的高级白玻璃。
            return Color.white.opacity(0.8)
            
            // (💡 如果你依然坚持想要“凹陷感”的深色，可以解除下面这行的注释看看效果：)
            // return Color.black.opacity(0.05)
        } else {
            // 深色模式下：叠加一层稍微亮一点的深灰，让材质更深邃
            #if os(macOS)
            return Color(nsColor: .controlBackgroundColor).opacity(0.5)
            #else
            return Color(uiColor: .secondarySystemGroupedBackground).opacity(0.5)
            #endif
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            configuration.label
            configuration.content
        }
        .padding(20)
        // ==========================================
        // 🎨 背景调色魔法 (利用 ZStack 明确层级)
        // ==========================================
        .background(
            ZStack {
                // 第 1 层 (最底层)：苹果极薄毛玻璃，负责吸收和模糊主页背景
                Rectangle().fill(.ultraThinMaterial)
                
                // 第 2 层 (盖在玻璃上)：你的调色蒙版！用来去掉系统灰，或者涂上任何你想要的色调
                Rectangle().fill(cardTintColor)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(colorScheme == .light ? 0.08 : 0.2), radius: 12, x: 0, y: 4)
    }
}
