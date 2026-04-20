#if os(macOS)
internal import Combine
import AppKit
import SwiftData
import SwiftUI

// MARK: - ✨ 导航与模块枚举

/// 定义 macOS 侧边栏所有顶级导航模块的严格枚举集合。
///
/// 作为整个应用的“骨架”，它实现了 `Identifiable` 协议，
/// 直接用于驱动 SwiftUI 原生 `List(selection:)` 以及右侧内容区的路由切换。
enum NavigationModule: String, CaseIterable, Identifiable {
    case home = "阅读主页"
    case gallery = "全景画廊"
    case roaming3d = "全息书境"
    case inspiration = "灵感碎片"
    case yearly = "年度轨迹"
    case monthly = "月度记录"

    /// 满足 Identifiable 协议，使用其自身的字符串原始值作为唯一 ID。
    var id: String { rawValue }

    /// 为侧边栏列表提供标准化的 SF Symbols 系统图标。
    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .gallery: return "photo.on.rectangle.angled"
        case .roaming3d: return "cube.transparent.fill"
        case .inspiration: return "quote.bubble.fill"
        case .yearly: return "calendar.circle"
        case .monthly: return "chart.bar.doc.horizontal"
        }
    }
}

// MARK: - ✨ 主视图入口

/// macOS 版本的应用底层核心容器。
///
/// **架构与职责：**
/// 这是整个 macOS App 启动后看到的第一个视图（Root View）。它的核心职责包括：
/// 1. **顶层骨架**：利用 `NavigationSplitView` 构建经典的 Mac 应用（左侧边栏 + 右侧主内容区）的两栏布局。
/// 2. **全局路由流转**：通过监听 `selectedModule` 的状态切换，将渲染流转发至对应的子系统视图。
/// 3. **统一 Z 轴堆栈管理**：在整个 App 层级之上，管理了书籍详情页 (`BookDetailView`) 的覆盖出场，以及全局庆祝撒花 (`ConfettiView`) 的展示层叠关系。
/// 4. **外观控制注入**：拦截系统层面的 `NSApp.appearance`，在此处完成基于用户设置的秒级“深/浅/跟随系统”换肤魔法。
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    /// 拉取全局配置单例（按更新时间降序取最新），用于获取主题颜色等跨模块偏好。
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]

    @ObservedObject private var syncEngine = SyncEngine.shared
    @Query(filter: #Predicate<Book> { $0.status?.rawValue == "READING" }) var readingBooks: [Book]
    
    // UI 统一排版参数 (作为只读变量提供给全局共享)
    let pagePadding: CGFloat = 30
    let widgetSpacing: CGFloat = 40
    let sectionSpacing: CGFloat = 60

    // MARK: 核心流转与路由状态
    
    /// 用于处理从各个模块封面点击放大到详情页的共享动画命名空间。
    @Namespace private var namespace
    /// 被所有子模块共享。一旦被赋值为特定 `Book`，则触发全局弹层覆盖进入详情页；置为 `nil` 则退回主界面。
    @State private var selectedBook: Book? = nil
    /// 辅助 `selectedBook`，记录是由哪一个卡片 ID 触发了详情展开，确保动画回弹时不重影。
    @State private var activeCoverID: String = ""
    
    /// 侧边栏当前高亮选中的子模块，默认落地在首页。
    @State private var selectedModule: NavigationModule? = .home
    /// 强制开启双栏模式。
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    /// 管理右上方“+”号唤起的图书录入表单面板。
    @State private var showAddModal = false

    /// 💡 编译器极速推导的核心：将 body 拆分为极简的主干
    var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                sidebarContent
            } detail: {
                detailContent
            }
            .background(WindowTransparentEffect())
            .sheet(isPresented: $showAddModal) { BookEditorSheet(isPresented: $showAddModal, bookToEdit: nil) }
            // 模块切换时，安全清理未关闭的书籍详情页
            .onChange(of: selectedModule) { _, _ in withAnimation { selectedBook = nil } }
            // 监听外设层通过 Notification 发出的建书指令
            .onReceive(NotificationCenter.default.publisher(for: .showAddBookModal)) { _ in showAddModal = true }
            
            // 全局常驻隐形撒花视图池
            ConfettiView()
                .ignoresSafeArea() // 确保粒子穿透顶栏和侧边栏
        }
        // ✨ 核心注入：在生命周期起点强制渲染深浅色并校验 CloudKit 冗余配置
        .onAppear {
            applyTheme(configs.first?.appTheme ?? "system")
            pruneDuplicateConfigs(context: modelContext)
        }
        .ignoresSafeArea(edges: .top)
    }
    
    // MARK: - 原生级外观引擎
    
    /// 瞬间接管并覆写 macOS 顶层系统的主题外观环境。
    ///
    /// - Parameter theme: 用户设置的字符串 ("light", "dark", "system")。
    /// - 注意：该调用包含对 `NSApp` 的修改，必须推送到 `main` 异步队列防止并发线程阻塞。
    private func applyTheme(_ theme: String) {
        DispatchQueue.main.async {
            switch theme {
            case "light": NSApp.appearance = NSAppearance(named: .aqua)
            case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
            default: NSApp.appearance = nil // 瞬间把控制权还给 macOS 系统，实现自适应
            }
        }
    }
    
    // MARK: - 🧩 子视图碎片化：侧边栏

    /// 左侧固定的半透明导航边栏。
    private var sidebarContent: some View {
        List(selection: $selectedModule) {
            Section(header: Text("探索").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)) {
                NavigationLink(value: NavigationModule.home) { Label(NavigationModule.home.rawValue, systemImage: NavigationModule.home.systemImage) }
                NavigationLink(value: NavigationModule.gallery) { Label(NavigationModule.gallery.rawValue, systemImage: NavigationModule.gallery.systemImage) }
                NavigationLink(value: NavigationModule.roaming3d) { Label(NavigationModule.roaming3d.rawValue, systemImage: NavigationModule.roaming3d.systemImage) }
                NavigationLink(value: NavigationModule.inspiration) { Label(NavigationModule.inspiration.rawValue, systemImage: NavigationModule.inspiration.systemImage) }
            }

            Section(header: Text("归档").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)) {
                NavigationLink(value: NavigationModule.yearly) { Label(NavigationModule.yearly.rawValue, systemImage: NavigationModule.yearly.systemImage) }
                NavigationLink(value: NavigationModule.monthly) { Label(NavigationModule.monthly.rawValue, systemImage: NavigationModule.monthly.systemImage) }
            }
        }
        .listStyle(.sidebar)
        .font(.system(size: 15, weight: .medium))
        .environment(\.defaultMinListRowHeight, 38)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        // 侧边栏底部停靠：今日阅读目标完成度徽章
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 12) {
                    DailyProgressRingView()
                        .frame(width: 18, height: 18)

                    Text("今日阅读目标")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: - 🧩 子视图碎片化：主内容区

    /// 管理基础模块与详情页浮层关系的内容核心容器。
    private var detailContent: some View {
        ZStack(alignment: .top) {
            // 底层路由墙，执行平滑的淡入淡出过场动画
            mainModuleRouter
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.3), value: selectedModule)
                .zIndex(0)

            // 若命中选书状态，则渲染并从右侧推入沉浸式的详情页面
            if let book = selectedBook {
                BookDetailView(book: book, namespace: namespace, activeCoverID: $activeCoverID, selectedBook: $selectedBook)
                    .id(book.id)
                    .zIndex(1)
                    .transition(.move(edge: .trailing))
            }
        }
        .toolbar { globalToolbar }
    }

    // MARK: - 🧩 子视图碎片化：模块路由

    /// 一个纯净的 `@ViewBuilder` 交换机，依据当前的 `selectedModule` 下发对应的视图组件。
    @ViewBuilder
    private var mainModuleRouter: some View {
        switch selectedModule {
        case .home:
            FluidLibraryHomeView(namespace: namespace, selectedBook: $selectedBook, activeCoverID: $activeCoverID)
        case .gallery:
            ArchiveGalleryView(namespace: namespace, selectedBook: $selectedBook, activeCoverID: $activeCoverID)
        case .roaming3d:
            CarouselWidget(namespace: namespace, selectedBook: $selectedBook, activeCoverID: $activeCoverID)
        case .inspiration:
            InspirationWallView()
        case .yearly:
            YearlyTimelineView(namespace: namespace, selectedBook: $selectedBook, activeCoverID: $activeCoverID)
        case .monthly:
            MonthlyRecordView()
        case .none:
            ContentUnavailableView("请在左侧选择一个模块", systemImage: "sidebar.left")
        }
    }

    // MARK: - 🧩 子视图碎片化：全局工具栏

    /// macOS 原生顶部 Toolbar 的按钮组合装配中心。
    ///
    /// 该构建器具备上下文感知能力：
    /// - 若处于详情页，会渲染左上角的"返回"按钮。
    /// - 若处于 `home` 并未进入详情页，会提供右上角的"+"号按钮，以支持图书手动录入操作。
    @ToolbarContentBuilder
    private var globalToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            if selectedBook != nil {
                Button(action: { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { selectedBook = nil } }) {
                    Image(systemName: "chevron.left")
                    Text("返回")
                }
            }
        }

        // 这个隐形的弹簧会把左侧和右侧的组件死死顶到两边！
        ToolbarItem(placement: .principal) {
            Spacer()
        }

        if selectedModule == .home && selectedBook == nil {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddModal = true }) {
                    Image(systemName: "plus")
                }
                .help("新建图书")
            }
        }
    }
}

// MARK: - macOS 底层窗口透明特效

/// 提供 macOS 顶栏透明化效果的 `NSViewRepresentable` 桥接组件。
///
/// 它可以深入系统渲染层，获取宿主 `window`，并将其样式设置为 `.fullSizeContentView`
/// 且 `titlebarAppearsTransparent = true`。这是让整个 App 界面完全通透，背景可以深入侵入顶栏区域的基础魔法。
struct WindowTransparentEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
