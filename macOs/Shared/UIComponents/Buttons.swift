#if os(macOS)
import SwiftUI

enum AppPageHeaderMetrics {
    static let height: CGFloat = 128
}

struct AppPageHeader<TitleContent: View, TrailingContent: View, SecondaryContent: View>: View {
    let horizontalPadding: CGFloat
    let materialOpacity: Double
    let showsDivider: Bool
    let contentID: String
    @ViewBuilder let titleContent: () -> TitleContent
    @ViewBuilder let trailingContent: () -> TrailingContent
    @ViewBuilder let secondaryContent: () -> SecondaryContent

    init(
        horizontalPadding: CGFloat = 40,
        materialOpacity: Double = 0.85,
        showsDivider: Bool = true,
        contentID: String = "",
        @ViewBuilder titleContent: @escaping () -> TitleContent,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent = { EmptyView() },
        @ViewBuilder secondaryContent: @escaping () -> SecondaryContent = { EmptyView() }
    ) {
        self.horizontalPadding = horizontalPadding
        self.materialOpacity = materialOpacity
        self.showsDivider = showsDivider
        self.contentID = contentID
        self.titleContent = titleContent
        self.trailingContent = trailingContent
        self.secondaryContent = secondaryContent
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .trailing) {
                HStack {
                    titleContent()
                    Spacer(minLength: 24)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                trailingContent()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, horizontalPadding)
            .frame(height: AppPageHeaderMetrics.height - (showsDivider ? 1 : 0), alignment: .center)

            secondaryContent()

            if showsDivider {
                Divider().background(Color.primary.opacity(0.05))
            }
        }
        .contentShape(Rectangle())
        .frame(height: AppPageHeaderMetrics.height, alignment: .bottom)
        .transition(.opacity)
        .animation(.appContentFade, value: contentID)
        .background(Color.clear.background(.ultraThinMaterial).opacity(materialOpacity))
        .ignoresSafeArea(edges: .top)
    }
}

struct AppHeaderTitle: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
}
#endif
