#if os(macOS)
import SwiftUI

// MARK: - macOS 端偏好设置全局容器

/// 管理用户配置参数的 macOS 独立设置窗口（通常通过 Cmd+, 唤出）。
///
/// **架构特性：**
/// 采用了标准的顶部 `TabView` 进行子模块路由（常规配置、数据导入与备份、成就墙）。
/// 内置了一套全局的 `systemMessage` 悬浮气泡系统，供其内部的所有子页面进行成功状态回调时展示。
struct SettingsView: View {
    /// 全局浮窗通知绑定变量。子视图如需抛出保存成功或导入成功的吐司，赋值该字段即可。
    @State private var systemMessage: AttributedString? = nil
    
    /// 监听共享深浅色主题设置，用于部分不走响应式的底层重绘支持。
    @AppStorage("appTheme", store: SharedDatabase.shared.sharedDefaults)
    private var appTheme: Int = 0
    
    var body: some View {
        ZStack(alignment: .top) {
            // 路由导航区
            TabView {
                GeneralSettingsView(systemMessage: $systemMessage)
                    .tabItem { Label("常规", systemImage: "gearshape") }
                
                DataPanelSettingsView(systemMessage: $systemMessage)
                    .tabItem { Label("数据面板", systemImage: "externaldrive") }
                
                // ✨ 引入拆分后的硬核荣誉墙子页面
                AchievementWallView()
                    .tabItem { Label("成就", systemImage: "rosette") }
            }
            .frame(width: 800, height: 760)
            
            // 动态顶置通知胶囊
            if let msg = systemMessage {
                Text(msg)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                    .background(.regularMaterial) // 系统原生磨砂玻璃
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.15), radius: 10, y: 5)
                    .padding(.top, 24)
                    .transition(.move(edge: .top).combined(with: .scale(scale: 0.9)).combined(with: .opacity))
                    .zIndex(100)
            }
        }
    }
}
#endif
