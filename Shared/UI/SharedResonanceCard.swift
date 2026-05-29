#if os(macOS) || os(iOS)
internal import Combine
import SwiftUI

// MARK: - 思想共鸣（共享）

/// 书摘轮播卡片，内部元素自适应撑满空间，无固定尺寸。
/// 调用方通过 `.frame()` 控制最终宽高。
/// 20 秒自动切换，支持点击手动切换。
struct SharedResonanceCard: View {
    let excerpts: [ResonanceDataPoint]

    @State private var currentIndex: Int = 0
    @Environment(\.colorScheme) private var colorScheme

    private let timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

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
                            .id(currentIndex)
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
        guard excerpts.indices.contains(currentIndex) else {
            return excerpts.first!
        }
        return excerpts[currentIndex]
    }

    private func switchExcerpt() {
        guard !excerpts.isEmpty else { return }
        withAnimation(.spring(duration: 0.8)) {
            currentIndex = (currentIndex + 1) % excerpts.count
        }
    }
}

#if DEBUG
#Preview("思想共鸣") {
    SharedResonanceCard(excerpts: [
        ResonanceDataPoint(content: "黑暗森林法则最让我震撼的是，它揭示了宇宙社会学的冷酷真相。", source: "三体"),
        ResonanceDataPoint(content: "历史从不重复自己，但它总是押韵。", source: "人类简史"),
    ])
    .frame(height: 240)
    .padding()
}
#endif
#endif
