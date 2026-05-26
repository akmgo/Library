#if os(macOS)
import SwiftUI
import AppKit

struct GeneralSettingsView: View {
    @Binding var systemMessage: AttributedString?
    @Environment(\.colorScheme) private var colorScheme
    
    // ================= 原生轻量化本地存储 =================
    // 采用 AppStorage 替代 SwiftData，实现跨组件瞬间响应且无需查库
    
    @AppStorage("appTheme", store: SharedDatabase.shared.sharedDefaults)
    private var appTheme: String = "system"
    
    @AppStorage("defaultStartupTab", store: SharedDatabase.shared.sharedDefaults)
    private var defaultStartupTab: String = "home"
    
    var body: some View {
        Form {
            // ================= 1. 外观与体验 =================
            Section {
                SettingsRow(icon: "macwindow", iconColor: .blue, title: "外观主题", subtitle: "强制覆盖 macOS 系统的深浅色模式") {
                    Picker("", selection: $appTheme) {
                        Text("跟随系统").tag("system")
                        Text("浅色模式").tag("light")
                        Text("深色模式").tag("dark")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 140)
                    .onChange(of: appTheme) { _, newValue in applyTheme(newValue) }
                }
            } header: { Text("外观").font(.system(size: 13, weight: .bold)) }
            
            // ================= 2. 操作指引 (纯展示) =================
            Section {
                SettingsRow(icon: "magnifyingglass", iconColor: .blue, title: "全局搜索", subtitle: "在任意页面快速搜索书籍、摘录与笔记") {
                    ShortcutBadge(text: "⌘ K")
                }

                SettingsRow(icon: "plus.square.fill", iconColor: .orange, title: "快速录入", subtitle: "脑暴时刻，迅速记录闪念或添加新书籍") {
                    ShortcutBadge(text: "⌘ N")
                }

                SettingsRow(icon: "cursorarrow.click.2", iconColor: .gray, title: "编辑内容实体", subtitle: "在画廊或碎片的瀑布流中，快速修改具体内容") {
                    ShortcutBadge(text: "双击卡片")
                }

                SettingsRow(icon: "arrow.down.right.and.arrow.up.left", iconColor: .gray, title: "退出全屏沉浸", subtitle: "在长文沉浸阅读模式下，快速返回主界面的流") {
                    ShortcutBadge(text: "Esc")
                }
            } header: { Text("操作与快捷键指引").font(.system(size: 13, weight: .bold)) }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.primaryBackground(for: colorScheme))
    }
    
    // MARK: - 辅助逻辑
    
    private func applyTheme(_ theme: String) {
        DispatchQueue.main.async {
            switch theme {
            case "light": NSApp.appearance = NSAppearance(named: .aqua)
            case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
            default: NSApp.appearance = nil
            }
        }
    }
}

// MARK: - 🎨 专属 UI 组件：拟物化按键徽章

/// 用于渲染精致的“键帽”风格文本，极具 macOS 原生味道。
private struct ShortcutBadge: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            // 模拟真实键帽的立体感
            .background(AppColors.innerBlock(for: colorScheme))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.06), radius: 1, x: 0, y: 1)
    }
}

#Preview("常规设置预览") {
    GeneralSettingsView(systemMessage: .constant(nil))
        .frame(width: 500, height: 600)
        // 模拟 TabView 传下来的底色
        .background(AppColors.primaryBackground(for: .light))
}
#endif
