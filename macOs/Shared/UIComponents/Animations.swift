#if os(macOS)
import SwiftUI

// MARK: - ✨ 1. 全局动画时间曲线 (Animation)

extension Animation {
    
    /// 【流体几何】
    /// 适用场景：数据洗牌、分类过滤、视图形态切换 (如网格大小改变)。
    /// 视觉感受：具有强烈的粘滞感和物理重量，仿佛卡片是被水流推到新位置的。
    static var appFluidSpring: Animation {
        .spring(response: 0.45, dampingFraction: 0.85)
    }
    
    /// 【轻快响应】
    /// 适用场景：按钮按压、鼠标悬浮 (Hover)、搜索框呼出、菜单展开。
    /// 视觉感受：干脆利落，绝对不拖泥带水，给用户最快速的交互确认。
    static var appSnappy: Animation {
        .spring(response: 0.25, dampingFraction: 0.7)
    }
    
    /// 【深沉过渡】
    /// 适用场景：页面级大路由切换、大面积的背景光晕叠化。
    static var appSlowFade: Animation {
        .easeInOut(duration: 0.4)
    }
}

// MARK: - ✨ 2. 全局转场效果 (AnyTransition)

extension AnyTransition {
    
    /// 【呼吸滑翔】(Glide & Fade)
    /// 适用场景：全景画廊、灵感碎片中的卡片入场与出场。
    /// 视觉感受：微微缩小 (0.96) 并带有极轻微的 Y 轴下沉，出现时仿佛从水面浮起并定格。
    static var appCardGlide: AnyTransition {
        .scale(scale: 0.96)
        .combined(with: .opacity)
        .combined(with: .offset(y: 12)) // 从略微靠下的位置浮上来
    }
    
    /// 【空间推移】(Push & Dissolve)
    /// 适用场景：年度/月度阅读等具有“时间流向”概念的视图切换。
    /// - Parameter isForward: 是否是走向未来（如 2025 -> 2026），决定了滑动方向。
    static func appTemporalPush(isForward: Bool) -> AnyTransition {
        let insertionEdge: Edge = isForward ? .trailing : .leading
        let removalEdge: Edge = isForward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }
}
#endif
