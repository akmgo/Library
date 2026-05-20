import SwiftUI

// MARK: - 全局原生卡片样式

/// 注入灵魂的苹果原生风格 `GroupBox` 样式扩展。
///
/// 该样式彻底重写了 SwiftUI 默认的 `GroupBox` 渲染逻辑，将其改造为具有
/// 高级毛玻璃透视感、1px 高光边框以及自适应深浅模式阴影的 **拟物化玻璃卡片**。
///
/// **设计哲学：**
/// - 浅色模式下：叠加 80% 透明度的纯白色洗掉系统毛玻璃自带的脏灰感，呈现清透的白玻璃质感。
/// - 深色模式下：叠加半透明深灰，让深邃的背景透出，同时保持卡片内容的清晰度。
///
/// - 注意: 可通过在层级顶端调用 `.groupBoxStyle(NativeWidgetGroupBoxStyle())` 将其应用到全局。
struct NativeWidgetGroupBoxStyle: GroupBoxStyle {
    @Environment(\.colorScheme) var colorScheme
    
    private var cardTintColor: Color {
        AppColors.secondaryBackground(for: colorScheme).opacity(colorScheme == .light ? 0.86 : 0.62)
    }

    private var shadow: (color: Color, radius: CGFloat, y: CGFloat) {
        colorScheme == .light ? AppShadows.soft : AppShadows.softDark
    }
    
    /// 构建包含内容与样式的最终视图。
    ///
    /// - Parameter configuration: 包含 `label`（标题部分）和 `content`（主体内容）的配置对象。
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            configuration.label
            configuration.content
        }
        .padding(AppSpacing.l)
        // ==========================================
        // 🎨 背景调色魔法 (利用 ZStack 明确层级)
        // ==========================================
        .background(
            ZStack {
                // 第 1 层 (最底层)：苹果极薄毛玻璃，负责吸收和模糊主页背景
                Rectangle().fill(AppMaterials.card)
                
                // 第 2 层 (盖在玻璃上)：调色蒙版！用来去掉系统灰，或者涂上任何你想要的色调
                Rectangle().fill(cardTintColor)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }
}
