#if os(macOS)
import SwiftUI

enum AppPageHeaderMetrics {
    static let height: CGFloat = 128
    static let titleLeadingInset: CGFloat = 60
    static let trailingInset: CGFloat = 30
    static let contentBottomInset: CGFloat = 18
    static let titleTrailingGap: CGFloat = 32
    static let statsItemMinWidth: CGFloat = 0
    static let statsItemHeight: CGFloat = 56
    static let statsItemSpacing: CGFloat = 12
    static let statsValueFontSize: CGFloat = 24
    static let statsLabelFontSize: CGFloat = 12
    static let statsValueLabelSpacing: CGFloat = 4
    static let statsVerticalOffset: CGFloat = -3
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

struct AppHeaderStatItem: Identifiable, Hashable {
    let id: String
    let value: String
    let label: String

    init(_ value: String, label: String) {
        self.id = label
        self.value = value
        self.label = label
    }

    init(_ value: Int, label: String) {
        self.id = label
        self.value = "\(value)"
        self.label = label
    }

    init(current: Int, target: Int, label: String) {
        self.id = label
        self.value = "\(current)/\(target)"
        self.label = label
    }

    var numericValue: Int {
        if let slashIndex = value.firstIndex(of: "/") {
            return Int(value[..<slashIndex]) ?? 0
        }
        return Int(value) ?? 0
    }
}

struct AppHeaderStatsView: View {
    let items: [AppHeaderStatItem]

    @Environment(\.colorScheme) private var colorScheme

    init(_ items: [AppHeaderStatItem]) {
        self.items = items
    }

    var body: some View {
        let topItems = items.sorted { $0.numericValue > $1.numericValue }.prefix(3)
        HStack(spacing: 10) {
            ForEach(Array(topItems)) { item in
                StatCapsule(item: item)
            }
        }
        .offset(y: AppPageHeaderMetrics.statsVerticalOffset)
        .accessibilityElement(children: .combine)
    }
}

private struct StatCapsule: View {
    let item: AppHeaderStatItem

    @Environment(\.colorScheme) private var colorScheme

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.05)
    }

    private var fillColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.03)
            : Color.white.opacity(0.22)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(item.value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(item.label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule(style: .continuous).fill(fillColor))
        .glassEffect(in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}
#endif
