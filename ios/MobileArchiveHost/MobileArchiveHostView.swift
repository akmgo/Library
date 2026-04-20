#if os(iOS)
import SwiftUI
import SwiftData

// MARK: - ✨ 沉浸式归档主控视图

/// 包装年度轨迹 (`MobileYearlyTimelineView`) 与月度记录 (`MobileMonthlyRecordView`) 的主控容器。
///
/// **交互特性：**
/// 顶部提供一个原生的 Segmented Control（分段选择器）以供无缝切换。
/// 监听设备旋转状态，在横屏 (`isLandscape`) 模式下，自动隐藏底部的 TabBar，为数据图表释放极致的纵向视野。
struct MobileArchiveHostView: View {
    let monthTitle: String
    @State private var archiveMode: Int = 0
    
    // 🍏 监听屏幕旋转状态
    @Environment(\.verticalSizeClass) var verticalSizeClass
    var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ✨ 恢复展示：始终保留两小模块的切换标题
                Picker("归档视图", selection: $archiveMode) {
                    Text("年度轨迹").tag(0)
                    Text("月历记录").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 16)
                
                // 子视图渲染路由
                if archiveMode == 0 {
                    MobileYearlyTimelineView()
                } else {
                    MobileMonthlyRecordView(monthTitle: monthTitle)
                }
            }
            .navigationTitle(archiveMode == 0 ? "年度轨迹" : "月历记录")
            .navigationBarTitleDisplayMode(.inline)
            // 🍏 使用原生底色
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            // ✨ 核心魔法：横屏时只隐藏底部的 TabBar 以释放纵向空间，保留顶部导航
            .toolbar(isLandscape ? .hidden : .visible, for: .tabBar)
            .animation(.easeInOut(duration: 0.3), value: isLandscape)
        }
    }
}
#endif
