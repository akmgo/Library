#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

// MARK: - ✨ 导航与模块枚举
enum NavigationModule: String, CaseIterable, Identifiable {
    case home = "阅读主页"
    case discovery = "云海拾贝"
    case gallery = "全景画廊"
    case inspiration = "灵感碎片"
    case verses = "墨香画卷"
    case yearly = "年度轨迹"
    case monthly = "月度记录"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .discovery: return "sparkles.tv"
        case .gallery: return "photo.on.rectangle.angled"
        case .inspiration: return "quote.bubble.fill"
        case .verses: return "paintbrush.pointed.fill"
        case .yearly: return "calendar.circle"
        case .monthly: return "chart.bar.doc.horizontal"
        }
    }
}

// MARK: - 🌌 专属流体底层画幕
struct AmbientFluidCanvas: View {
    @State private var phase: Float = 0.0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            let baseOp = colorScheme == .dark ? 0.12 : 0.06

            MeshGradient(
                width: 3, height: 3,
                points: [
                    .init(0, 0), .init(0.5, 0), .init(1, 0),
                    .init(0, 0.5), .init(0.5 + 0.06 * sin(phase), 0.5 + 0.06 * cos(phase)), .init(1, 0.5),
                    .init(0, 1), .init(0.5, 1), .init(1, 1)
                ],
                colors: [
                    Color.indigo.opacity(baseOp * 1.5), Color.purple.opacity(baseOp * 0.8), Color.teal.opacity(baseOp * 1.2),
                    Color.blue.opacity(baseOp * 0.9), Color.indigo.opacity(baseOp * 1.1), Color.purple.opacity(baseOp * 0.9),
                    Color.teal.opacity(baseOp * 1.2), Color.blue.opacity(baseOp * 1.3), Color.indigo.opacity(baseOp * 1.0)
                ]
            )
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.linear(duration: 15).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - ✨ 主视图入口
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    // ✨ 核心修复：使用 AppStorage 替代数据库查询，性能更优
    @AppStorage("appTheme", store: SharedDatabase.shared.sharedDefaults)
    private var appTheme: String = "system"
    
    @AppStorage("defaultStartupTab", store: SharedDatabase.shared.sharedDefaults)
    private var defaultStartupTab: String = "home"

    @State private var selectedBook: Book? = nil
    @State private var selectedModule: NavigationModule? = nil // 初始设为 nil，等待 onAppear 赋值
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    @State private var showAddModal = false
    @State private var showAddSnippetModal = false

    @State private var globalSearchText: String = ""
    @State private var isSearchActive: Bool = false

    @State private var galleryActiveTab: ArchiveFilterTab = .all
    @State private var gallerySortType: GallerySortType = .newest
    @State private var galleryScaleIndex: Double = 2.0
    @State private var galleryIsBatchEditMode: Bool = false
    @State private var gallerySelectedBooks: Set<String> = []

    @State private var inspirationContentType: InspirationContentType = .all
    @State private var inspirationSortType: GallerySortType = .newest
    @State private var inspirationIsRandomRoam: Bool = true
    @State private var inspirationShuffleTrigger: Int = 0
    @State private var inspirationIsBatchEditMode: Bool = false
    @State private var inspirationSelectedSnippets: Set<String> = []
    
    @State private var versesActiveCategory: VersesFilterTab = .all
    @State private var versesSortType: GallerySortType = .newest
    @State private var versesIsCarouselMode: Bool = false
    @State private var versesIsBatchEditMode: Bool = false
    @State private var versesSelectedSnippets: Set<String> = []

    @State private var yearlySelectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var yearlyAvailableYears: [Int] = [Calendar.current.component(.year, from: Date())]

    @State private var detailShowEditSheet = false
    @State private var detailShowDeleteAlert = false

    @State private var showCloudSpotlight = false

    var body: some View {
        ZStack {
            AmbientFluidCanvas().zIndex(0)

            NavigationSplitView(columnVisibility: $columnVisibility) {
                sidebarContent
            } detail: {
                detailContent
            }
            .zIndex(1)
            .background(WindowTransparentEffect())
            .background(
                Button("") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showCloudSpotlight.toggle()
                    }
                }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
            )
            .overlay {
                if showCloudSpotlight { CloudSearchSpotlightView(isPresented: $showCloudSpotlight) }
            }

            ConfettiView().ignoresSafeArea().allowsHitTesting(false).zIndex(2)
        }
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showAddModal) { BookEditorSheet(isPresented: $showAddModal, bookToEdit: nil) }
        .sheet(isPresented: $showAddSnippetModal) { SnippetEditorSheet(isPresented: $showAddSnippetModal) }
        .onChange(of: selectedModule) { _, _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selectedBook = nil }
            globalSearchText = ""
            isSearchActive = false
            galleryIsBatchEditMode = false
            inspirationIsBatchEditMode = false
            versesIsBatchEditMode = false
            versesSelectedSnippets.removeAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAddBookModal)) { _ in
            showAddModal = true
        }
        // ✨ 挂载初始化逻辑
        .onAppear {
            applyTheme(appTheme)
            setupInitialModule()
        }
        // ✨ 监听主题切换
        .onChange(of: appTheme) { _, newTheme in
            applyTheme(newTheme)
        }
        .background(
            Button("") {
                if selectedModule == .verses {
                    showAddSnippetModal = true
                } else if [.home, .gallery, .inspiration].contains(selectedModule) {
                    showAddModal = true
                }
            }
            .keyboardShortcut("n", modifiers: .command)
            .opacity(0)
        )
    }
    
    // MARK: - 辅助逻辑

    /// 解析用户设置，设定 App 启动时的默认板块
    private func setupInitialModule() {
        switch defaultStartupTab {
        case "home": selectedModule = .home
        case "gallery": selectedModule = .gallery
        case "monthly": selectedModule = .monthly
        case "yearly": selectedModule = .yearly
        case "inspiration": selectedModule = .inspiration
        case "verses": selectedModule = .verses
        default: selectedModule = .home
        }
    }

    private func applyTheme(_ theme: String) {
        DispatchQueue.main.async {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                switch theme {
                case "light": NSApp.appearance = NSAppearance(named: .aqua)
                case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
                default: NSApp.appearance = nil
                }
            }
        }
    }

    private var sidebarContent: some View {
        List(selection: $selectedModule) {
            Section(header: Text("探索").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)) {
                NavigationLink(value: NavigationModule.home) { Label(NavigationModule.home.rawValue, systemImage: NavigationModule.home.systemImage) }
                NavigationLink(value: NavigationModule.discovery) { Label(NavigationModule.discovery.rawValue, systemImage: NavigationModule.discovery.systemImage) }
                NavigationLink(value: NavigationModule.gallery) { Label(NavigationModule.gallery.rawValue, systemImage: NavigationModule.gallery.systemImage) }
                NavigationLink(value: NavigationModule.inspiration) { Label(NavigationModule.inspiration.rawValue, systemImage: NavigationModule.inspiration.systemImage) }
            }

            Section(header: Text("归档").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)) {
                NavigationLink(value: NavigationModule.verses) { Label(NavigationModule.verses.rawValue, systemImage: NavigationModule.verses.systemImage) }
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
                    DailyProgressRingView().frame(width: 18, height: 18)
                    Text("今日阅读目标").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                    Spacer()
                }.padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
    }

    private var detailContent: some View {
        ZStack(alignment: .top) {
            mainModuleRouter
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.animation(.appSlowFade))
                .zIndex(0)

            if let book = selectedBook {
                BookDetailView(
                    book: book,
                    selectedBook: $selectedBook,
                    showEditSheet: $detailShowEditSheet,
                    showDeleteAlert: $detailShowDeleteAlert
                )
                .id(book.id)
                .zIndex(1)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .toolbar { globalToolbar }
        .animation(.appFluidSpring, value: selectedBook)
    }

    @ViewBuilder
    private var mainModuleRouter: some View {
        switch selectedModule {
        case .home:
            FluidLibraryHomeView(selectedBook: $selectedBook)
        case .discovery:
            DiscoveryView()
        case .gallery:
            ArchiveGalleryView(
                selectedBook: $selectedBook, activeTab: $galleryActiveTab, searchText: $globalSearchText, sortType: $gallerySortType,
                scaleIndex: $galleryScaleIndex, isBatchEditMode: $galleryIsBatchEditMode, selectedBooksForBatch: $gallerySelectedBooks
            )
        case .inspiration:
            InspirationWallView(
                selectedBook: $selectedBook, contentType: $inspirationContentType, sortType: $inspirationSortType, isRandomRoam: $inspirationIsRandomRoam,
                searchText: $globalSearchText, shuffleTrigger: $inspirationShuffleTrigger, isBatchEditMode: $inspirationIsBatchEditMode, selectedSnippetsForBatch: $inspirationSelectedSnippets
            )
        case .verses:
            InkGalleryView(
                activeCategory: $versesActiveCategory,
                searchText: $globalSearchText,
                sortType: $versesSortType,
                isCarouselMode: $versesIsCarouselMode,
                isBatchEditMode: $versesIsBatchEditMode,
                selectedSnippetsForBatch: $versesSelectedSnippets
            )
        case .yearly:
            YearlyTimelineView(selectedBook: $selectedBook, selectedYear: $yearlySelectedYear, availableYears: $yearlyAvailableYears)
        case .monthly:
            MonthlyRecordView()
        case .none:
            ContentUnavailableView("请在左侧选择一个模块", systemImage: "sidebar.left")
        }
    }

    // MARK: - 🧩 全局统一静态工具栏
    @ToolbarContentBuilder
    private var globalToolbar: some ToolbarContent {
        if selectedBook != nil {
            ToolbarItem(placement: .navigation) {
                GlobalBackButton { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selectedBook = nil } }
            }
            ToolbarItem { Spacer() }
            ToolbarItem {
                ControlGroup {
                    Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { detailShowEditSheet = true } }) { Image(systemName: "square.and.pencil").font(.system(size: 15)) }.help("编辑")
                    Button(action: { detailShowDeleteAlert = true }) { Image(systemName: "trash").font(.system(size: 15)) }.help("删除")
                }
            }
        } else {
            ToolbarItem { Spacer() }

            // 各模块专属菜单
            if selectedModule == .gallery {
                ToolbarItem { GridScaleMenuButton(scaleIndex: $galleryScaleIndex) }
            } else if selectedModule == .inspiration {
                ToolbarItem { RoamModeMenuButton(isRandom: $inspirationIsRandomRoam) { inspirationShuffleTrigger += 1 } }
            } else if selectedModule == .yearly {
                ToolbarItem { YearSelectorMenuButton(selectedYear: $yearlySelectedYear, availableYears: yearlyAvailableYears, onSelect: { year in yearlySelectedYear = year }) }
            }

            // 过滤与批处理
            if selectedModule == .gallery {
                ToolbarItem {
                    ControlGroup {
                        FilterMenuButton(selection: $galleryActiveTab, options: ArchiveFilterTab.allCases, activeIcon: "line.3.horizontal.decrease.circle.fill", inactiveIcon: "line.3.horizontal.decrease", isFiltered: galleryActiveTab != .all)
                        BatchEditToggleButton(isEditing: $galleryIsBatchEditMode) { withAnimation(.appSnappy) { galleryIsBatchEditMode.toggle(); gallerySelectedBooks.removeAll() } }
                        SortMenuButton(selection: $gallerySortType, options: GallerySortType.allCases)
                    }
                }
            } else if selectedModule == .inspiration {
                ToolbarItem {
                    ControlGroup {
                        FilterMenuButton(selection: $inspirationContentType, options: InspirationContentType.allCases, activeIcon: "line.3.horizontal.decrease.circle.fill", inactiveIcon: "line.3.horizontal.decrease", isFiltered: inspirationContentType != .all)
                        BatchEditToggleButton(isEditing: $inspirationIsBatchEditMode) { withAnimation(.appSnappy) { inspirationIsBatchEditMode.toggle(); inspirationSelectedSnippets.removeAll() } }
                        SortMenuButton(selection: $inspirationSortType, options: GallerySortType.allCases)
                    }
                }
            } else if selectedModule == .verses {
                ToolbarItem {
                    ControlGroup {
                        FilterMenuButton(selection: $versesActiveCategory, options: VersesFilterTab.allCases, activeIcon: "line.3.horizontal.decrease.circle.fill", inactiveIcon: "line.3.horizontal.decrease", isFiltered: versesActiveCategory != .all)
                        DisplayModeToggleButton(isCarousel: $versesIsCarouselMode)
                        BatchEditToggleButton(isEditing: $versesIsBatchEditMode) { withAnimation(.appSnappy) { versesIsBatchEditMode.toggle(); versesSelectedSnippets.removeAll() } }
                        SortMenuButton(selection: $versesSortType, options: GallerySortType.allCases)
                    }
                }
            }

            // 新增按钮
            if [.home, .gallery, .inspiration, .verses].contains(selectedModule) {
                ToolbarItem {
                    ControlGroup {
                        Button(action: {
                            if selectedModule == .verses { showAddSnippetModal = true } else { NotificationCenter.default.post(name: .showAddBookModal, object: nil) }
                        }) { Image(systemName: "plus").font(.system(size: 16)) }.help(selectedModule == .verses ? "新增笔墨" : "添加书籍")
                    }
                }
            }

            // 激活全局搜索栏
            if [.gallery, .inspiration, .verses].contains(selectedModule) {
                ToolbarItem {
                    ControlGroup {
                        ExpandableSearchItem(searchText: $globalSearchText, isActive: $isSearchActive)
                    }
                }
            }
        }
    }
}

struct WindowTransparentEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.backgroundColor = .clear
                window.isOpaque = false
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
