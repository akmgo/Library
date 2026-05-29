import SwiftUI
import WidgetKit

// MARK: - 全局小组件入口包裹器

/// 应用级别的所有桌面小组件注册入口大总管。
@main
struct MyLibraryWidgetsBundle: WidgetBundle {
    var body: some Widget {

        FocusHeroWidget()

        StatsGridWidget()

        MomentumChartWidget()

        MomentumWidget()

        YearlyHeatmapWidget()

        ResonanceWaveWidget()

        DesktopDashboardWidget()

        #if os(iOS)
        ReadingTimerLiveActivity()
        #endif
    }
}
