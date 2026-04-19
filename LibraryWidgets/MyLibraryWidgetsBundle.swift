import SwiftUI
import WidgetKit

@main
struct MyLibraryWidgetsBundle1: WidgetBundle {
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
