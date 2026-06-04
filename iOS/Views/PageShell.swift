import SwiftUI

struct PageShell<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                content()
            }
            .padding(.horizontal, AppTheme.pageHorizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(colorScheme).ignoresSafeArea())
        .animation(AppTheme.contentAnimation, value: colorScheme)
    }
}

#if DEBUG
#Preview("Page Shell") {
    PreviewHost { _ in
        NavigationStack {
            PageShell {
                AppCard {
                    SectionHeader(title: "页面标题", subtitle: "示例")
                    Text("这里展示页面默认背景、滚动容器、间距和卡片位置。")
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }

                AppEmptyState(title: "空状态", message: "用于观察空状态和页面间距。")
            }
        }
    }
}
#endif
