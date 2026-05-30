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
struct MobileRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    /// ✨ 核心修复 1：抛弃数据库，直接从共享的 UserDefaults 中读取主题偏好
    @AppStorage("appTheme", store: SharedDatabase.shared.sharedDefaults)
    private var appTheme: String = "system"
    
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]
    
    @State private var selectedTab = 0
    @State private var showingAddBookSheet = false
    @State private var showingSettings = false
    @State private var showingGlobalSearch = false
    @State private var highlightedExcerptID: String?

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // ================= 1. 主页 =================
                NavigationStack {
                    MobileHomeView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                HStack(spacing: AppSpacing.s) {
                                    Button(action: { showingAddBookSheet = true }) {
                                        Image(systemName: "plus")
                                    }
                                    Button(action: { showingSettings = true }) {
                                        Image(systemName: "gearshape")
                                    }
                                }
                            }
                        }
                }
                .tabItem { Label("主页", systemImage: "house.fill") }.tag(0)

                // ================= 2. 画廊 =================
                MobileBookGalleryView()
                    .tabItem { Label("画廊", systemImage: "books.vertical.fill") }.tag(1)

                // ================= 3. 摘录 =================
                MobileExcerptsView(highlightedExcerptID: $highlightedExcerptID)
                    .tabItem { Label("摘录", systemImage: "quote.bubble.fill") }.tag(2)

                // ================= 4. 年度 =================
                NavigationStack {
                    MobileYearlyTimelineView()
                }
                .tabItem { Label("年度", systemImage: "calendar") }.tag(3)

                // ================= 5. 月度 =================
                NavigationStack {
                    MobileMonthlyRecordView()
                }
                .tabItem { Label("月度", systemImage: "calendar.day.timeline.left") }.tag(4)
            }
            .background(AppColors.primaryBackground(for: colorScheme).ignoresSafeArea())

            if showingGlobalSearch {
                MobileGlobalSearchView(
                    isPresented: $showingGlobalSearch,
                    selectedTab: $selectedTab,
                    highlightedExcerptID: $highlightedExcerptID
                )
                    .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
                    .zIndex(100)
            }
        }
        .onAppear {
            // ✨ 核心修复 2：启动时直接应用本地主题配置
            applyTheme(appTheme)
            pruneDuplicateConfigs(context: modelContext)
        }
        // ✨ 核心修复 3：监听跨视图的主题变化（比如从设置页修改后，全局立刻响应）
        .onChange(of: appTheme) { _, newTheme in
            applyTheme(newTheme)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAddBookModal)) { _ in
            showingAddBookSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showGlobalSearch)) { _ in
            guard !showingGlobalSearch else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                showingGlobalSearch = true
            }
        }
        .sheet(isPresented: $showingAddBookSheet) {
            MobileBookEditorSheet()
        }
        .sheet(isPresented: $showingSettings) {
            MobileSettingsView()
        }
        .background(
            Button("") {
                withAnimation(.easeOut(duration: 0.18)) {
                    showingGlobalSearch = true
                }
            }
            .keyboardShortcut("k", modifiers: .command)
            .opacity(0)
        )
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

#if DEBUG
#Preview("App 主框架") {
    PreviewWithData {
        MobileRootView()
    }
}
#endif


#endif
