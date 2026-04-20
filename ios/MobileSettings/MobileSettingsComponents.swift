#if os(iOS)
import SwiftUI

// MARK: - ⚙️ 辅助微型组件库

/// 设置列表左侧的统一渐变图标修饰器。
struct SettingIcon: View {
    let icon: String
    let color: Color
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.gradient)
                .frame(width: 28, height: 28)
            
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.trailing, 4)
    }
}

/// 荣誉与徽章墙的微型陈列卡片。
/// 支持传入 `isUnlocked` 来动态切换高亮渐变色或灰阶锁定状态。
struct MobileBadgeView: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? color.opacity(0.15) : Color.secondary.opacity(0.05))
                    .frame(width: 64, height: 64)
                Circle()
                    .fill(isUnlocked ? color.gradient : Color.secondary.opacity(0.1).gradient)
                    .frame(width: 48, height: 48)
                Image(systemName: isUnlocked ? icon : "lock.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isUnlocked ? .white : .secondary.opacity(0.4))
            }
            .shadow(color: isUnlocked ? color.opacity(0.3) : .clear, radius: 6, y: 3)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(isUnlocked ? .primary : .secondary)
                Text(subtitle)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .frame(width: 80)
        .grayscale(isUnlocked ? 0 : 1)
        .opacity(isUnlocked ? 1.0 : 0.6)
    }
}
#endif
