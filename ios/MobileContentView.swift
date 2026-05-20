#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 📱 iOS 根容器视图

/// iOS 应用的全局入口与底层 `TabView` 导航控制器。
///
/// **架构职责：**
/// 1. **主路由枢纽**：通过原生的 `TabView` 串联五大核心模块（含新增的全局探索模块）。
/// 2. **全局环境注入**：使用 @AppStorage 接管本地主题，不再依赖数据库。
/// 3. **全局弹窗拦截**：无感唤起添加书籍面板。
struct MobileContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    /// ✨ 核心修复 1：抛弃数据库，直接从共享的 UserDefaults 中读取主题偏好
    @AppStorage("appTheme", store: SharedDatabase.shared.sharedDefaults)
    private var appTheme: String = "system"
    
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
            }
            .tabItem { Label("主页", systemImage: "house.fill") }.tag(0)
            
            // ================= 2. 画廊 =================
            MobileGalleryView()
                .tabItem { Label("画廊", systemImage: "books.vertical.fill") }.tag(1)
            
            // ================= 3. 日常摘录 (✨ 取代了之前的搜索 Tab) =================
            MobileInkGalleryView()
                .tabItem { Label("摘录", systemImage: "text.quote") }.tag(2)
            
            // ================= 4. 碎片 =================
            MobileInspirationWallView()
                .tabItem { Label("碎片", systemImage: "quote.bubble.fill") }.tag(3)
            
            // ================= 5. 归档 =================
            MobileArchiveHostView()
                .tabItem { Label("归档", systemImage: "clock.arrow.circlepath") }.tag(4)
        }
        .background(AppColors.primaryBackground(for: colorScheme).ignoresSafeArea())
        .onAppear {
            // ✨ 核心修复 2：启动时直接应用本地主题配置
            applyTheme(appTheme)
            pruneDuplicateConfigs(context: modelContext)
        }
        // ✨ 核心修复 3：监听跨视图的主题变化（比如从设置页修改后，全局立刻响应）
        .onChange(of: appTheme) { _, newTheme in
            applyTheme(newTheme)
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
    
    private func applyTheme(_ theme: String) {
        let style: UIUserInterfaceStyle = {
            switch theme {
            case "light": return .light
            case "dark": return .dark
            default: return .unspecified
            }
        }()
            
        // ✨ 优化：使用 keyWindow (兼容 iOS 15+ 的更安全写法)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.keyWindow?.overrideUserInterfaceStyle = style
        }
    }
}
#endif
