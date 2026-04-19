#if os(macOS)
import SwiftUI

// 全局触发撒花的通知名称
extension Notification.Name {
    static let triggerConfetti = Notification.Name("triggerConfetti")
}

struct ConfettiView: View {
    @State private var isAnimating = false
    @State private var opacity = 0.0
    
    // 简单的纸屑结构
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
    
    private func fireConfetti() {
        particles = (0..<80).map { _ in Particle() }
        isAnimating = false
        opacity = 1.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isAnimating = true // 触发掉落
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 1.0)) {
                opacity = 0.0 // 动画结束后淡出
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                particles.removeAll()
            }
        }
    }
}
#endif
