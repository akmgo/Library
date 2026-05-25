import SwiftUI

// MARK: - 全局原生卡片样式

/// 为 iOS 首页卡片注入原生玻璃质感。
///
/// 使用系统原生 `glassEffect` 实现毛玻璃透视效果与自适应深浅模式阴影。
///
/// - 注意: 可通过在层级顶端调用 `.groupBoxStyle(NativeWidgetGroupBoxStyle())` 将其应用到全局。
struct NativeWidgetGroupBoxStyle: GroupBoxStyle {
    @Environment(\.colorScheme) var colorScheme

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
        .glassCardSurface()
        .shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }
}
