#if os(macOS)
import SwiftUI

// MARK: - ✨ 3D 单个卡片组件 (macOS 专属)

/// 构建全息画廊的原子级渲染核心：具有 3D 透视物理引擎的书籍卡片。
///
/// **渲染与几何引擎：**
/// 这是一个纯数据驱动的组件，它接收自身距离 C 位的差距 (`diff`)，并自动执行高度复杂的数学推演：
/// - **X轴重定位**：根据 `centerOffset` 及 `sideSpacing`，自动推演向左或向右的折叠推移。
/// - **旋转与缩放**：采用经典的 Y 轴 60度角翻转。距离 C 位越远，比例越小。
/// - **光影材质**：包含仿物理的暗部递进蒙版（离中心越远越暗）、顶层的线性白光高光（模拟真实书脊反光），以及带镜面渐变消失效果的底部地面倒影。
///
/// - Parameters:
///   - diff: 当前卡片距离中心视角的绝对步数差距（负数为左，正数为右，0 为 C 位）。
///   - isSpotlighted: 当开启聚光灯模式时，触发该元素的放大或深层下潜逻辑。
struct CoverFlowCardItem: View {
    let book: Book
    let diff: Int
    
    let centerOffset: CGFloat
    let sideSpacing: CGFloat
    let isSpotlighted: Bool
    
    let cardWidth: CGFloat = 300
    let cardHeight: CGFloat = 450
    
    var body: some View {
        let isCenter = diff == 0
        let rawAbsDiff = abs(CGFloat(diff))
        
        // --- 核心物理计算引擎 ---
        
        /// 对特定的视图物理量执行基于距离的线性插值平滑递减
        func linearMapPercent(startVal: CGFloat, endVal: CGFloat) -> CGFloat {
            if isCenter { return 1.0 }
            let normalizeFactor = max(0.0, 1.0 - rawAbsDiff / 12.0)
            return endVal + (startVal - endVal) * normalizeFactor
        }
        
        let rotateY: Double = isCenter ? 0 : (isSpotlighted ? 0 : (diff < 0 ? 60 : -60))
        let scale: CGFloat = isCenter ? (isSpotlighted ? 1.15 : 1.0) : (isSpotlighted ? 0.82 : max(0.55, 1.0 - rawAbsDiff * 0.05))
        let alignYOffset: CGFloat = cardHeight * (1.0 - scale) / 2.0
        let spotlightJump: CGFloat = 40
        let activeCenterOffset = isSpotlighted ? centerOffset * 1.5 : centerOffset
        let activeSideSpacing = isSpotlighted ? 45.0 : sideSpacing
        
        let translateX: CGFloat = isCenter ? 0 : (diff < 0 ? -activeCenterOffset - (rawAbsDiff - 1) * activeSideSpacing : activeCenterOffset + (rawAbsDiff - 1) * activeSideSpacing)
                
        let darknessOpacity: Double = isCenter ? 0.0 : (isSpotlighted ? 0.15 : min(0.4, Double(rawAbsDiff) * 0.1))
        let reflectionLocation = linearMapPercent(startVal: 0.8, endVal: 0.5)

        let safeTitle = book.title ?? "未知书名"
        let safeAuthor = (book.author ?? "未知作者").uppercased()
        
        // --- 渲染树 ---
        return ZStack(alignment: .top) {
            // 1. 顶部悬浮的隐形标题与作者 (仅 C 位可见)
            VStack(spacing: 8) {
                Text(safeTitle)
                    .font(.system(size: isSpotlighted ? 40 : 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
                
                Text(safeAuthor)
                    .font(.system(size: isSpotlighted ? 16 : 13, weight: .bold, design: .rounded))
                    .tracking(4)
                    .foregroundColor(.secondary)
            }
            .frame(width: cardWidth + 300)
            .opacity(isCenter ? 1 : 0)
            .offset(y: isCenter ? (isSpotlighted ? -120 : -90) : -70)
            .zIndex(3)
            
            // 2. 封面物理组合体
            ZStack {
                // 底层接触阴影 (赋予书本重量感)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(isCenter ? 0.25 : 0.05))
                    .blur(radius: isCenter ? (isSpotlighted ? 25 : 12) : 4)
                    .offset(y: isCenter ? (isSpotlighted ? 30 : 20) : 6)
                    .scaleEffect(0.95)
                    .zIndex(0)

                // 物理倒影效果
                LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                    .frame(width: cardWidth, height: cardHeight).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .rotation3DEffect(.degrees(180), axis: (x: 1, y: 0, z: 0)) // 垂直翻转
                    .mask(
                        LinearGradient(stops: [
                            .init(color: .black.opacity(0.7), location: 0.0),
                            .init(color: .clear, location: Double(reflectionLocation)) // 地面消失渐变
                        ], startPoint: .top, endPoint: .bottom)
                    )
                    .offset(y: cardHeight + (isCenter && isSpotlighted ? spotlightJump * 2 + 10 : 2))
                    .opacity(isCenter ? 0.8 : 0.2)
                    .zIndex(1)
                
                // 核心实体卡片
                ZStack {
                    LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                        .frame(width: cardWidth, height: cardHeight)
                    
                    // ✨ 书脊物理高光渐变：模拟光线打在曲面玻璃上的反光
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.35), location: 0.0),
                            .init(color: .white.opacity(0.0), location: 0.08)
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                    
                    // 侧边暗部衰减蒙版
                    Color.black.opacity(darknessOpacity)
                    
                    // 1px 细丝边框收边
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(isCenter ? 0.15 : 0.08), lineWidth: 1)
                }
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .zIndex(2)
            }
            .frame(width: cardWidth, height: cardHeight)
            .zIndex(1)
        }
        // 挂载顶层物理转换参数
        .frame(width: cardWidth, height: 850)
        .rotation3DEffect(.degrees(rotateY), axis: (x: 0, y: 1, z: 0), perspective: 0.3)
        .scaleEffect(scale)
        .offset(x: translateX, y: alignYOffset)
        .offset(y: isSpotlighted ? (isCenter ? -spotlightJump : 15) : 0)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: diff)
        .animation(.spring(response: 0.55, dampingFraction: 0.75), value: isSpotlighted)
    }
}
#endif
