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
