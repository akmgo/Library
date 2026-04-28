#if os(macOS)
import SwiftUI
internal import Combine


/// 桌面端的极简时间与日期展示组件。
///
/// **设计逻辑：**
/// 采用了复古机械翻页钟的视觉逻辑，数字变化时带有丝滑的上下滑动转场。
/// 去除了冒号的特效，保持极致的简单与克制。
// MARK: - 🕰️ 桌面级环境时钟 (Ambient Clock - 玻璃晶体版)
struct FluidAmbientClock: View {
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var hourString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH"
        return formatter.string(from: currentTime)
    }
    
    var minuteString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm"
        return formatter.string(from: currentTime)
    }
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: currentTime)
    }
    
    var body: some View {
        let accentColor = Color.indigo
        
        VStack(alignment: .center, spacing: 25) {
            HStack(spacing: 16) {
                GiantTimeBlock(value: hourString, label: "HOURS")
                
                Text(":")
                    .font(.system(size: 90, weight: .medium, design: .rounded))
                    .foregroundColor(accentColor)
                    .offset(y: -25)
                
                GiantTimeBlock(value: minuteString, label: "MINUTES")
            }
            
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(accentColor.opacity(0.8))
                Text(dateString)
                    .tracking(1)
            }
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            // ✨ 日期指示器变为细长的胶囊玻璃
            .glassEffect(in: .capsule)
        }
        // 我们不给整个时钟套玻璃外壳，这会让这两块“晶体”显得更加立体和悬浮
        .frame(height: 245)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
}

// MARK: - 🧱 带有滑动转场的玻璃时间晶体
private struct GiantTimeBlock: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // 中间的分割线（保留机械时钟的翻页感）
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 2)
                    .zIndex(1)
                
                Text(value)
                    .font(.system(size: 110, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary.opacity(0.85))
                    .id(value)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
            .frame(width: 160, height: 160)
            // ✨ 核心改变：直接把方块本身铸造成极其高定质感的液态玻璃
            .glassEffect(in: .rect(cornerRadius: 16.0))
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: value)
            
            Text(label)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(.secondary.opacity(0.4))
                .tracking(3)
        }
    }
}


#Preview() {
    FluidAmbientClock()
}

#endif
