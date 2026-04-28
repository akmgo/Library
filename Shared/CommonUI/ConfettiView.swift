#if os(macOS)
import SwiftUI

// MARK: - 撒花动画组件

/// 全局庆祝撒花粒子动画层 (仅限 macOS)。
///
/// 该视图应被放置在应用窗口的最顶层 (例如 `ZStack` 的最外层)。
/// 它会监听名为 `.triggerConfetti` 的系统通知，一旦接收到信号，
/// 便会在屏幕顶部生成数十个随机颜色、随机下落速度的粒子，并执行重力坠落的物理动画。
///
/// - 注意: 该视图的 `allowsHitTesting` 属性已被设置为 `false`，因此它永远不会阻挡用户对底层 UI 的点击事件。
struct ConfettiView: View {
    @State private var isAnimating = false
    @State private var opacity = 0.0
    
    /// 描述单个纸屑粒子的物理属性结构体
    struct Particle: Identifiable {
        let id = UUID()
        let x: CGFloat = CGFloat.random(in: 0.1...0.9)
        let color: Color = [.red, .blue, .green, .yellow, .orange, .purple, .pink].randomElement()!
        let duration: Double = Double.random(in: 2.0...3.5)
        let delay: Double = Double.random(in: 0...0.5)
    }
    
    @State private var particles: [Particle] = []
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: 10, height: 10)
                        // 动画状态切换时，Y坐标从屏幕顶部 (-20) 坠落到屏幕底部外部
                        .position(x: geo.size.width * particle.x, y: isAnimating ? geo.size.height + 20 : -20)
                        .animation(.easeIn(duration: particle.duration).delay(particle.delay), value: isAnimating)
                }
            }
            .opacity(opacity)
        }
        .allowsHitTesting(false) // 绝对不能阻挡用户的鼠标点击
        .onReceive(NotificationCenter.default.publisher(for: .triggerConfetti)) { _ in
            fireConfetti()
        }
    }
    
    /// 内部逻辑：触发撒花引擎。
    ///
    /// 初始化 80 个随机粒子实例，利用 GCD (`DispatchQueue.main.asyncAfter`)
    /// 精确控制粒子的生成、下落触发、最终淡出以及内存回收过程。
    private func fireConfetti() {
        particles = (0..<80).map { _ in Particle() }
        isAnimating = false
        opacity = 1.0
        
        // 延迟极短时间后开始坠落动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isAnimating = true // 触发掉落
        }
        
        // 4秒后开始清理战场
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 1.0)) {
                opacity = 0.0 // 动画结束后淡出
            }
            // 淡出完毕后释放内存
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                particles.removeAll()
            }
        }
    }
}
#endif
