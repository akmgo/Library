#if os(macOS)
import SwiftUI

enum AppPageHeaderMetrics {
    static let height: CGFloat = 128
    static let titleLeadingInset: CGFloat = 60
    static let trailingInset: CGFloat = 30
    static let contentBottomInset: CGFloat = 18
    static let titleTrailingGap: CGFloat = 32
}

struct AppPageHeader<TitleContent: View, TrailingContent: View, SecondaryContent: View>: View {
    let materialOpacity: Double
    let showsDivider: Bool
    let contentID: String
    @ViewBuilder let titleContent: () -> TitleContent
    @ViewBuilder let trailingContent: () -> TrailingContent
    @ViewBuilder let secondaryContent: () -> SecondaryContent

    init(
        materialOpacity: Double = 0.85,
        showsDivider: Bool = true,
        contentID: String = "",
        @ViewBuilder titleContent: @escaping () -> TitleContent,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent = { EmptyView() },
        @ViewBuilder secondaryContent: @escaping () -> SecondaryContent = { EmptyView() }
    ) {
        self.materialOpacity = materialOpacity
        self.showsDivider = showsDivider
        self.contentID = contentID
        self.titleContent = titleContent
        self.trailingContent = trailingContent
        self.secondaryContent = secondaryContent
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: AppPageHeaderMetrics.titleTrailingGap) {
                HStack(spacing: 0) {
                    titleContent()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                trailingContent()
                    .fixedSize(horizontal: true, vertical: true)
                    .frame(alignment: .bottomTrailing)
            }
            .padding(.leading, AppPageHeaderMetrics.titleLeadingInset)
            .padding(.trailing, AppPageHeaderMetrics.trailingInset)
            .padding(.bottom, AppPageHeaderMetrics.contentBottomInset)
            .frame(height: AppPageHeaderMetrics.height - (showsDivider ? 1 : 0), alignment: .bottom)

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
