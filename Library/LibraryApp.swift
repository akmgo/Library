import SwiftData
import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct LibraryApp: App {
    var body: some Scene {
        #if os(macOS)
        Window("Library", id: "mainWindow") {
            MacRootView()
                .frame(minWidth: 1200, idealWidth: 1420, minHeight: 900, idealHeight: 1080)
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
