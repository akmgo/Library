#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 📱 iOS 根容器视图

/// iOS 应用的全局入口与底层 `TabView` 导航控制器。
///
/// **架构职责：**
/// 1. **主路由枢纽**：通过原生的 `TabView` 串联主页、画廊、漫游、碎片和归档五大核心模块。
/// 2. **全局环境注入**：在 `onAppear` 时执行系统级深浅色主题覆盖 (`applyTheme`)，并触发 CloudKit 冗余配置清理 (`pruneDuplicateConfigs`)。
/// 3. **全局弹窗拦截**：监听 `.showAddBookModal` 通知，允许应用内的任意子层级无感唤起添加书籍面板。
struct MobileContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]
    
    @State private var selectedTab = 0
    @State private var showSettingsSheet = false
    @State private var showingAddBookSheet = false
    
    private var currentMonthString: String {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy年M月"; return formatter.string(from: Date())
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // ================= 1. 主页 =================
            NavigationStack {
                MobileHomeView()
                    .navigationTitle("我的书房")
            }
            .tabItem { Label("主页", systemImage: "house.fill") }.tag(0)
            
            // ================= 2. 画廊 =================
            MobileGalleryView()
                .tabItem { Label("画廊", systemImage: "books.vertical.fill") }.tag(1)
            
            // ================= 3. 漫游 =================
            MobileCarouselView()
                .tabItem { Label("漫游", systemImage: "square.stack.3d.down.right.fill") }.tag(2)
            
            // ================= 4. 碎片 =================
            MobileInspirationWallView()
                .tabItem { Label("碎片", systemImage: "quote.bubble.fill") }.tag(3)
            
            // ================= 5. 归档 =================
            MobileArchiveHostView(monthTitle: currentMonthString)
                .tabItem { Label("归档", systemImage: "clock.arrow.circlepath") }.tag(4)
        }
        // ✨ 核心注入：每次 App 启动，应用主题并静默清理 iCloud 同步产生的冗余配置
        .onAppear {
            applyTheme(configs.first?.appTheme ?? "system")
            pruneDuplicateConfigs(context: modelContext)
        }
        // 监听全局新建图书广播
        .onReceive(NotificationCenter.default.publisher(for: .showAddBookModal)) { _ in
            showingAddBookSheet = true
        }
        .sheet(isPresented: $showingAddBookSheet) {
            MobileBookEditorSheet()
        }
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                MobileSettingsView()
                    .navigationTitle("系统设置")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("完成") { showSettingsSheet = false }.fontWeight(.bold)
                        }
                    }
            }
            .presentationDetents([.large])
        }
    }
    
    // MARK: - 原生外观覆盖引擎
    
    /// 根据配置选项，强制接管当前 iOS 系统的 UI 界面风格。
    private func applyTheme(_ theme: String) {
        let style: UIUserInterfaceStyle = {
            switch theme {
            case "light": return .light
            case "dark": return .dark
            default: return .unspecified // 瞬间把控制权还给 iOS 系统自适应！
            }
        }()
            
        // 强行遍历所有窗口并应用
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
#endif
