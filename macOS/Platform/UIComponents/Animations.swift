#if os(macOS)
import SwiftUI

// MARK: - ✨ 1. 全局动画时间曲线 (Animation)

extension Animation {

    /// Control feedback: buttons, hover states, and compact toggles.
    static var appControlFeedback: Animation {
        .easeOut(duration: 0.16)
    }

    /// Content fade: calm data replacement and small content updates.
    static var appContentFade: Animation {
        .easeInOut(duration: 0.20)
    }

    /// Panel transition: sheets, overlays, and intentionally modal surfaces.
    static var appPanelTransition: Animation {
        .spring(response: 0.34, dampingFraction: 0.88)
    }

    /// Data change: grid reshaping, progress, charts, and filtered data updates.
    static var appDataChange: Animation {
        .spring(response: 0.32, dampingFraction: 0.9)
    }

    static var appFluidSpring: Animation { appDataChange }
    static var appSnappy: Animation { appControlFeedback }
    static var appSlowFade: Animation { appContentFade }
}

// MARK: - ✨ 2. 全局转场效果 (AnyTransition)

extension AnyTransition {
    
    /// 【呼吸滑翔】(Glide & Fade)
    /// 适用场景：全景画廊、灵感碎片中的卡片入场与出场。
    /// 视觉感受：微微缩小 (0.96) 并带有极轻微的 Y 轴下沉，出现时仿佛从水面浮起并定格。
    static var appCardGlide: AnyTransition {
        .opacity
        .combined(with: .offset(y: 8))
    }
    
    /// 【空间推移】(Push & Dissolve)
    /// 适用场景：年度/月度阅读等具有“时间流向”概念的视图切换。
    /// - Parameter isForward: 是否是走向未来（如 2025 -> 2026），决定了滑动方向。
    static func appTemporalPush(isForward: Bool) -> AnyTransition {
        .opacity.combined(with: .offset(y: 6))
    }
}
#endif
