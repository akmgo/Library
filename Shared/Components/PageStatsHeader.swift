#if os(macOS) || os(iOS)
import SwiftUI

// MARK: - Data Model

struct PageStatItemData {
    let title: String
    let value: String
    let color: Color
}

#if os(iOS)
enum MobilePageStatsHeaderMetrics {
    static let horizontalPadding: CGFloat = AppSpacing.l
    static let topPadding: CGFloat = AppSpacing.m
}

struct MobilePageStatsHeader: View {
    let items: [PageStatItemData]
    var bottomPadding: CGFloat = 0

    var body: some View {
        PageStatsHeader(items: items)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, MobilePageStatsHeaderMetrics.horizontalPadding)
            .padding(.top, MobilePageStatsHeaderMetrics.topPadding)
            .padding(.bottom, bottomPadding)
    }
}
#endif

// MARK: - Shared Stats Header

/// A four-column stats header used across iOS (standalone card) and macOS (inside AppPageHeader).
struct PageStatsHeader: View {
    let items: [PageStatItemData]
    var showsBackground: Bool = true

    var body: some View {
        if showsBackground {
            AppCard {
                statItems
            }
        } else {
            statItems
                .padding(.vertical, 12)
        }
    }

    private var statItems: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Divider()
                        .frame(height: 32)
                        .opacity(0.5)
                }
                PageStatItem(item: item)
            }
        }
    }
}

// MARK: - Single Stat Item

struct PageStatItem: View {
    let item: PageStatItemData

    var body: some View {
        VStack(spacing: 4) {
            Text(item.value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(item.color)
                .contentTransition(.numericText(value: Double(item.value) ?? 0))
            Text(item.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Compact Stats Row (macOS trailing)

/// A compact horizontal stats row for macOS AppPageHeader trailing content.
struct PageStatsCompact: View {
    let items: [PageStatItemData]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Divider()
                        .frame(height: 28)
                        .opacity(0.3)
                }
                VStack(spacing: 2) {
                    Text(item.value)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(item.color)
                        .contentTransition(.numericText(value: Double(item.value) ?? 0))
                    Text(item.title)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .fixedSize()
            }
        }
        .offset(y: -3)
    }
}
#endif
