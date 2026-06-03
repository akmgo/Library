import SwiftUI

struct PageShell<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 34, weight: .semibold))
                        .tracking(0)
                    Text(subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
                .padding(.bottom, 4)

                content()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(colorScheme).ignoresSafeArea())
    }
}
