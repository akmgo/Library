#if os(macOS)
import SwiftUI

/// 💎 通用 macOS 液态玻璃按钮底座
struct LiquidGlassButton: View {
    let icon: String
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                // 稍微加大一点尺寸，让毛玻璃质感更明显
                .frame(width: 32, height: 32)
                // ✨ 核心质感 1：半透明毛玻璃底座
                .background(.regularMaterial, in: Circle())
                // ✨ 核心质感 2：液态反光边缘 (高光)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                        .padding(0.5)
                        .blendMode(.overlay)
                )
                // ✨ 核心质感 3：微弱边框与悬浮阴影
                .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
                .shadow(color: .black.opacity(isHovering ? 0.08 : 0.04), radius: isHovering ? 4 : 2, y: isHovering ? 2 : 1)
                // 交互反馈
                .foregroundColor(isHovering ? .primary : .primary.opacity(0.75))
                .scaleEffect(isHovering ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
#endif
