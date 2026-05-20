#if os(macOS)
import SwiftUI
internal import Combine

// MARK: - 🌊 思想共鸣跑马灯

/// 在界面底部水平排列的、呈现单行极简诗意摘录的跑马灯组件。
/// 内部包含一个 `Timer.publish`，每隔 20 秒会自动触发轮播动画。
struct ResonanceWave: View {
    // 1. 接收纯数据数组，不再认识 SwiftData 的 Excerpt
    let excerpts: [ResonanceDataPoint]
    
    @State private var curIdx: Int = 0
    let timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()
    
    // 2. 安全的计算属性，返回纯 Struct
    var currentExcerpt: ResonanceDataPoint {
        if excerpts.isEmpty {
            return ResonanceDataPoint(content: "思想的留白，去阅读中遇见自己。", source: "系统寄语")
        }
        if excerpts.indices.contains(curIdx) {
            return excerpts[curIdx]
        } else {
            return excerpts.first!
        }
    }
    
    var body: some View {
        // ✨ 核心重构：抛弃 GroupBox，换上原生的液态玻璃舱
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            // 头部 Label
            HStack {
                Text("思想共鸣")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "quote.bubble.fill")
                    .foregroundColor(.indigo)
            }
            
            // 内容区
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                
                Spacer(minLength: 0)
                
                Text(currentExcerpt.content)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .lineSpacing(10)
                    .foregroundColor(.primary.opacity(0.85))
                    .lineLimit(8)
                    // 核心动画锚点
                    .id(curIdx)
                    .transition(.opacity.combined(with: .blurReplace))
                
                Spacer(minLength: 0)
                
                HStack {
                    Spacer()
                    Text("—— \(currentExcerpt.source)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(AppSpacing.xl)
        .glassEffect(in: .rect(cornerRadius: AppRadius.panel))
        .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        .onTapGesture { switchExcerpt() }
        .onReceive(timer) { _ in switchExcerpt() }
    }
    
    // 3. 将轮播逻辑提取出来，保持代码整洁
    private func switchExcerpt() {
        guard !excerpts.isEmpty else { return }
        withAnimation(.spring(duration: 0.8)) {
            curIdx = (curIdx + 1) % excerpts.count
        }
    }
}

#endif
