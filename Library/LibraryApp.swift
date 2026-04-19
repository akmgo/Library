import SwiftData
import SwiftUI
#if os(macOS)
import AppKit
#endif

extension Notification.Name {
    static let showAddBookModal = Notification.Name("showAddBookModal")
    static let forceSyncBooks = Notification.Name("ForceSyncBooks")
}

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        NSApp.setActivationPolicy(.accessory) // 隐藏 Dock 图标
        return false // 不退出程序
    }
}
#endif

@main
struct MyLibraryApp: App {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var scenePhase

    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        #if os(macOS)
        // ==========================================
        // 🖥️ 场景 1：Mac 端专属窗口配置
        // ==========================================
        Window("MyLibrary", id: "mainWindow") {
            ContentView()
                // 1. 核心：卡死窗口的最小尺寸
                .frame(minWidth: 1200, idealWidth: 1420, minHeight: 900, idealHeight: 1080)
                .onAppear {
                    SyncEngine.shared.handleScenePhase(.active)
                }
                .overlay(ConfettiView())
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        // 2. 核心：设定程序第一次全新打开时的默认尺寸
        .defaultSize(width: 1420, height: 1080)
        // 3. 核心：告诉系统，窗口缩小的极限就是 ContentView 设定的 min 尺寸
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .onChange(of: scenePhase) { _, newPhase in
            SyncEngine.shared.handleScenePhase(newPhase)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建图书...") { NotificationCenter.default.post(name: .showAddBookModal, object: nil) }
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
        .modelContainer(SharedDatabase.shared.container)

        #else
        // ==========================================
        // 📱 场景 2：iOS 端专属窗口配置
        // ==========================================
        WindowGroup {
            MobileContentView()
        }
        .modelContainer(SharedDatabase.shared.container)
        #endif

        #if os(macOS)
        MenuBarExtra("MyLibrary", systemImage: "books.vertical.fill") {
            Button("显示阅读主页") {
                NSApp.setActivationPolicy(.regular) // 恢复 Dock
                openWindow(id: "mainWindow")

                // ✨ 修复多窗口问题：强制将唯一窗口提到最前面
                for window in NSApp.windows where window.title == "MyLibrary" {
                    window.makeKeyAndOrderFront(nil)
                }
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Divider()

            Button("立刻同步数据") {
                print("🖱️ [状态栏] 点击了手动同步按钮！")
                SyncEngine.shared.performFullSync()
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()

            Button("完全退出 MyLibrary") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }

        Settings {
            SettingsView()
                .modelContainer(SharedDatabase.shared.container)
        }
        .modelContainer(SharedDatabase.shared.container)
        #endif
    }
}

