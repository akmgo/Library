#if os(iOS)
import SwiftData
import SwiftUI

#if os(iOS)
import SwiftData
import SwiftUI

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
        // ✨ 核心注入 2：每次 App 启动，静默清理由于 iCloud 同步产生的冗余配置
        .onAppear {
            applyTheme(configs.first?.appTheme ?? "system")
            pruneDuplicateConfigs(context: modelContext)
        }
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
    
    private func applyTheme(_ theme: String) {
        let style: UIUserInterfaceStyle = {
            switch theme {
            case "light": return .light
            case "dark": return .dark
            default: return .unspecified // 👈 瞬间把控制权还给 iOS 系统！
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
// MARK: - ✨ 沉浸式归档主控视图

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
                
                // 子视图渲染
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
