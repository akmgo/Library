#if os(macOS)
import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - ✨ 导航与模块枚举

enum NavigationModule: String, CaseIterable, Identifiable {
    case home = "阅读主页"
    case gallery = "全景画廊"
    case excerpts = "摘录"
    case yearly = "年度轨迹"
    case monthly = "月度记录"

    var id: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .gallery: return "photo.on.rectangle.angled"
        case .excerpts: return "quote.bubble.fill"
        case .yearly: return "calendar.circle"
        case .monthly: return "chart.bar.doc.horizontal"
        }
    }
}

// MARK: - ✨ 主视图入口

struct ContentView: View {
    /// 获取刚才导入的书籍
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Environment(\.openWindow) private var openWindow // ✨ 召唤新窗口的魔法棒

    @AppStorage("appTheme", store: SharedDatabase.shared.sharedDefaults)
    private var appTheme: String = "system"

    @State private var selectedBook: Book? = nil
    @State private var selectedModule: NavigationModule? = .home
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    @State private var showAddExcerptModal = false

    @State private var yearlySelectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var yearlyAvailableYears: [Int] = [Calendar.current.component(.year, from: Date())]

    @State private var detailShowEditSheet = false
    @State private var detailShowDeleteAlert = false

    @State private var showBookMetadataSpotlight = false
    @State private var showGlobalSpotlight = false

    @State private var showOPDSBrowser = false

    var body: some View {
        ZStack {
            AppColors.primaryBackground(for: colorScheme)
                .ignoresSafeArea()
                .zIndex(0)

            NavigationSplitView(columnVisibility: $columnVisibility) {
                sidebarContent
            } detail: {
                detailContent
            }
            .zIndex(1)
            .background(AppColors.primaryBackground(for: colorScheme))

            ConfettiView().ignoresSafeArea().allowsHitTesting(false).zIndex(2)
        }
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showAddExcerptModal) { ExcerptEditorSheet(isPresented: $showAddExcerptModal) }
        .overlay {
            if showBookMetadataSpotlight {
                BookMetadataSpotlightSearchView(isPresented: $showBookMetadataSpotlight)
                    .zIndex(20)
            }

            if showGlobalSpotlight {
                GlobalSpotlightSearchView(
                    isPresented: $showGlobalSpotlight,
                    selectedModule: $selectedModule,
                    selectedBook: $selectedBook
                )
                .zIndex(30)
            }
        }
        .background(
            Button("") {
                withAnimation(.easeOut(duration: 0.16)) {
                    showGlobalSpotlight = true
                }
            }
            .keyboardShortcut("k", modifiers: .command)
            .opacity(0)
        )
        .onChange(of: selectedModule) { _, _ in
            selectedBook = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAddBookModal)) { _ in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                showBookMetadataSpotlight = true
            }
        }
        .onAppear {
            applyTheme(appTheme)
        }
        .onChange(of: appTheme) { _, newTheme in
            applyTheme(newTheme)
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
                NavigationLink(value: NavigationModule.gallery) { Label(NavigationModule.gallery.rawValue, systemImage: NavigationModule.gallery.systemImage) }
                NavigationLink(value: NavigationModule.excerpts) { Label(NavigationModule.excerpts.rawValue, systemImage: NavigationModule.excerpts.systemImage) }
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
                    DailyProgressRingView().frame(width: 18, height: 18)
                    Text("今日阅读目标").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                    Spacer()
                }.padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        ZStack(alignment: .top) {
            mainModuleRouter
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            }
        }
    }

    @ViewBuilder
    private var mainModuleRouter: some View {
        switch selectedModule {
        case .home:
            HomeView(selectedBook: $selectedBook)
        case .gallery:
            GalleryView(selectedBook: $selectedBook)
        case .excerpts:
            InspirationWallView(selectedBook: $selectedBook)
        case .yearly:
            YearlyTimelineView(selectedBook: $selectedBook, selectedYear: $yearlySelectedYear, availableYears: $yearlyAvailableYears)
        case .monthly:
            MonthlyRecordView()
        case .none:
            ContentUnavailableView("请在左侧选择一个模块", systemImage: "sidebar.left")
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
