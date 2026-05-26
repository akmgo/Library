#if os(iOS)
import SwiftUI
import SwiftData

struct MobileArchiveHostView: View {
    // 移除不必要的入参，改为由视图内部调度
    @State private var archiveMode: Int = 0
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    var isLandscape: Bool { verticalSizeClass == .compact }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部分段选择器
                Picker("归档视图", selection: $archiveMode) {
                    Text("年度轨迹").tag(0)
                    Text("月历记录").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, 10)
                .padding(.bottom, 16)
                
                // 内容区
                Group {
                    if archiveMode == 0 {
                        MobileYearlyTimelineView()
                    } else {
                        // ✨ 修复：现在 MonthlyRecordView 采用连续滚动逻辑，不再需要外部传入单一月份
                        MobileMonthlyRecordView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(AppColors.primaryBackground(for: colorScheme).ignoresSafeArea())
            .toolbar(isLandscape ? .hidden : .visible, for: .tabBar)
        }
    }
}

#if DEBUG
#Preview("存档总览") {
    PreviewWithData {
        MobileArchiveHostView()
    }
}
#endif


#endif
