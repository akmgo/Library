#if os(macOS)
internal import Combine
import AppKit
import SwiftData
import SwiftUI

// MARK: - ✨ 导航与模块枚举

enum NavigationModule: String, CaseIterable, Identifiable {
    case home = "阅读主页"
    case gallery = "全景画廊"
    case roaming3d = "全息书境"
    case inspiration = "灵感碎片"
    case yearly = "年度轨迹"
    case monthly = "月度记录"

    var id: String { rawValue }

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

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]

    @ObservedObject private var syncEngine = SyncEngine.shared
    @Query(filter: #Predicate<Book> { $0.status?.rawValue == "READING" }) var readingBooks: [Book]
    let pagePadding: CGFloat = 30
    let widgetSpacing: CGFloat = 40
    let sectionSpacing: CGFloat = 60

    // 核心流转状态
    @Namespace private var namespace
    @State private var selectedBook: Book? = nil
    @State private var activeCoverID: String = ""
    @State private var selectedModule: NavigationModule? = .home
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    /// 弹窗状态
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
            .onChange(of: selectedModule) { _, _ in withAnimation { selectedBook = nil } }
            .onReceive(NotificationCenter.default.publisher(for: .showAddBookModal)) { _ in showAddModal = true }
            
            ConfettiView()
                .ignoresSafeArea() // 确保全屏飘落
        }
        // ✨ 核心注入：在最外层直接应用深浅色配置
        .onAppear {
            applyTheme(configs.first?.appTheme ?? "system")
            pruneDuplicateConfigs(context: modelContext)
        }
        .ignoresSafeArea(edges: .top)
    }
    
    // ✨ 2. macOS 原生级换肤魔法 (瞬间生效)
        private func applyTheme(_ theme: String) {
            DispatchQueue.main.async {
                switch theme {
                case "light": NSApp.appearance = NSAppearance(named: .aqua)
                case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
                default: NSApp.appearance = nil // 👈 瞬间把控制权还给 macOS 系统！
                }
            }
        }
    
    // MARK: - 🧩 子视图碎片化：侧边栏

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

    private var detailContent: some View {
        ZStack(alignment: .top) {
            mainModuleRouter
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.3), value: selectedModule)
                .zIndex(0)

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

        ToolbarItem(placement: .principal) {
            Spacer() // 这个隐形的弹簧会把左侧和右侧的组件死死顶到两边！
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

// MARK: - 窗口透明特效

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
