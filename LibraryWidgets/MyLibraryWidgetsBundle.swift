import SwiftUI
import WidgetKit

// MARK: - 全局小组件入口包裹器

/// 应用级别的所有桌面小组件注册入口大总管。
@main
struct MyLibraryWidgetsBundle: WidgetBundle {
    var body: some Widget {
        
        FocusCoverWidget()
        StatsGridWidget()
        MomentumChartWidget()
        
        // ✨ 必须加上这一段！告诉系统我们要启动灵动岛
        #if os(iOS)
        ReadingLiveActivity()
        #endif
        
        MomentumWidget()
        
        YearlyHeatmapWidget()
        
        ResonanceWaveWidget()
        
        ReadingFocusWidget()
        
        DesktopDashboardWidget()
                
    }
}
