import SwiftData
import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct LibraryApp: App {
    var body: some Scene {
        #if os(macOS)
        // ==========================================
        // 🖥️ 场景 1：Mac 端专属窗口配置
        // ==========================================
        Window("Library", id: "mainWindow") {
            ContentView()
                // 1. 核心：卡死窗口的最小尺寸
                .frame(minWidth: 1200, idealWidth: 1420, minHeight: 900, idealHeight: 1080)
                .overlay(ConfettiView())
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        // 2. 核心：设定程序第一次全新打开时的默认尺寸
        .defaultSize(width: 1420, height: 1080)
        // 3. 核心：告诉系统，窗口缩小的极限就是 ContentView 设定的 min 尺寸
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建图书...") { NotificationCenter.default.post(name: .showAddBookModal, object: nil) }
                    .keyboardShortcut("n", modifiers: .command)
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
            MobileContentView()
        }
        .modelContainer(SharedDatabase.shared.container)
        #endif
    }
}
