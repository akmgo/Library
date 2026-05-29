import SwiftData
import SwiftUI
#if os(macOS)
import AppKit
#endif

#if os(macOS)
// MARK: - Dock 图标深色模式跟随

/// 监听系统主题变化，动态切换 Dock 栏中的应用图标。
/// Xcode 26 的 asset catalog 编译器不再从 Contents.json 的 appearance
/// 变体生成暗色 .icns，因此通过运行时 NSApp.applicationIconImage 绕行。
@MainActor
final class DockIconThemeObserver {
    private let lightImage: NSImage?
    private let darkImage: NSImage?

    init() {
        lightImage = NSImage(named: "AppIconLight")
        darkImage = NSImage(named: "AppIconDark")
        applyCurrentAppearance()
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(themeChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }

    @objc private func themeChanged(_ note: Notification) {
        applyCurrentAppearance()
    }

    private func applyCurrentAppearance() {
        let isDark = NSApp.effectiveAppearance.name == .darkAqua
            || NSApp.effectiveAppearance.name == .vibrantDark
        NSApp.applicationIconImage = isDark ? darkImage : lightImage
    }
}
#endif

@main
struct LibraryApp: App {
    #if os(macOS)
    @State private var dockIconObserver: DockIconThemeObserver?
    #endif

    var body: some Scene {
        #if os(macOS)
        // ==========================================
        // 🖥️ 场景 1：Mac 端专属窗口配置
        // ==========================================
        Window("Library", id: "mainWindow") {
            MacRootView()
                .frame(minWidth: 1200, idealWidth: 1420, minHeight: 900, idealHeight: 1080)
                .onAppear {
                    if dockIconObserver == nil {
                        dockIconObserver = DockIconThemeObserver()
                    }
                }
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1420, height: 1080)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("搜索并导入图书...") { NotificationCenter.default.post(name: .showAddBookModal, object: nil) }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .appInfo) {
                Button("全局搜索") { NotificationCenter.default.post(name: .showGlobalSearch, object: nil) }
                    .keyboardShortcut("k", modifiers: .command)
            }
        }
        .modelContainer(SharedDatabase.shared.container)

        // macOS 专属设置界面
        Settings {
            SettingsView()
                .modelContainer(SharedDatabase.shared.container)
        }

        #else
        // ==========================================
        // 📱 场景 2：iOS 端专属窗口配置
        // ==========================================
        WindowGroup {
            MobileRootView()
        }
        .modelContainer(SharedDatabase.shared.container)
        #endif
    }
}
