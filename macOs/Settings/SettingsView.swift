#if os(macOS)
import SwiftUI
import SwiftData
import WidgetKit

// MARK: - ⚙️ macOS 端偏好设置全局容器

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]
    
    /// 全局浮窗通知绑定变量
    @State private var systemMessage: AttributedString? = nil
    
    var body: some View {
        ZStack(alignment: .top) {
            AppColors.primaryBackground(for: colorScheme)
                .ignoresSafeArea()

            if let config = configs.first {
                // ================= 路由导航区 =================
                TabView {
                    GeneralSettingsView(systemMessage: $systemMessage)
                        .tabItem { Label("常规", systemImage: "gearshape") }
                    
                    GoalSettingsView(config: config, systemMessage: $systemMessage)
                        .tabItem { Label("目标", systemImage: "target") }
                    
                    DataSettingsView(systemMessage: $systemMessage)
                        .tabItem { Label("数据", systemImage: "externaldrive") }
                    
                    AboutSettingsView()
                        .tabItem { Label("关于", systemImage: "info.circle") }
                }
                .frame(width: 560, height: 500)
                .onAppear {
                    if configs.count > 1 {
                        for i in 1 ..< configs.count { modelContext.delete(configs[i]) }
                        try? modelContext.save()
                    }
                }
            } else {
                VStack {
                    ProgressView()
                    Text("初始化配置中...").font(.caption).foregroundColor(.secondary).padding(.top, 8)
                }
                .frame(width: 560, height: 500)
                .onAppear { initializeConfig() }
            }
            
            // ================= 动态顶置通知胶囊 =================
            if let msg = systemMessage {
                Text(msg)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .appCapsuleStyle(tint: AppColors.readingAmber, fillOpacity: 0.15, strokeOpacity: 0.10)
                    .padding(.top, 20)
                    .transition(.move(edge: .top).combined(with: .scale(scale: 0.9)).combined(with: .opacity))
                    .zIndex(100)
            }
        }
    }
    
    private func initializeConfig() {
        let newConfig = UserConfig()
        modelContext.insert(newConfig)
        try? modelContext.save()
    }
}

#endif
