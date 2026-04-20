#if os(macOS)
import SwiftUI
import SwiftData
internal import Combine

// MARK: - 🌊 思想共鸣跑马灯

/// 在界面底部水平排列的、呈现单行极简诗意摘录的跑马灯组件。
/// 内部包含一个 `Timer.publish`，每隔 20 秒会自动触发轮播动画。
struct FluidResonanceWaveChart: View {
    let allExcerpts: [Excerpt]
    @State private var curIdx: Int = 0
    let timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()
    
    var excerpt: Excerpt {
        if allExcerpts.isEmpty { return .init(content: "思想的留白，去阅读中遇见自己。") }
        if allExcerpts.indices.contains(curIdx) { return allExcerpts[curIdx] } else { return allExcerpts.first! }
    }
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Spacer(minLength: 0)
                Text(excerpt.content ?? "").font(.system(size: 16, weight: .medium, design: .serif)).lineSpacing(10).foregroundColor(.primary.opacity(0.85)).lineLimit(8).id(curIdx).transition(.opacity.combined(with: .blurReplace))
                Spacer(minLength: 0)
                HStack { Spacer(); Text("—— \(excerpt.book?.title ?? "札记")").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(.secondary) }
            }
            .frame(maxHeight: .infinity)
        } label: {
            HStack { Text("思想共鸣").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.primary); Spacer(); Image(systemName: "quote.bubble.fill").foregroundColor(.indigo) }
        }
        .groupBoxStyle(NativeWidgetGroupBoxStyle())
        .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        .onTapGesture { withAnimation(.spring()) { if !allExcerpts.isEmpty { curIdx = (curIdx + 1) % allExcerpts.count } } }
        .onReceive(timer) { _ in guard !allExcerpts.isEmpty else { return }; withAnimation(.spring()) { curIdx = (curIdx + 1) % allExcerpts.count } }
    }
}
#endif
