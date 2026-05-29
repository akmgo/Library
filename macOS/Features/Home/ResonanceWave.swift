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
    @Environment(\.colorScheme) private var colorScheme
    let timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()
    
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                Text("思想共鸣")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "quote.bubble.fill")
                    .foregroundColor(.indigo)
            }

            if excerpts.isEmpty {
                Text("暂无摘录")
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    Spacer(minLength: 0)

                    Text(currentExcerpt.content)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .lineSpacing(10)
                        .foregroundColor(.primary.opacity(0.85))
                        .lineLimit(8)
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
        }
        }
        .onTapGesture { switchExcerpt() }
        .onReceive(timer) { _ in switchExcerpt() }
    }

    private var currentExcerpt: ResonanceDataPoint {
        guard excerpts.indices.contains(curIdx) else {
            return excerpts.first!
        }
        return excerpts[curIdx]
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
