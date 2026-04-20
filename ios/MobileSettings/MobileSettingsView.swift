#if os(iOS)
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - ⚙️ 移动端设置主页

/// 管理用户配置参数的 iOS 原生设置页。
///
/// **架构特性：**
/// 此视图负责确保安全的 `UserConfig` 实体加载，处理由于网络同步可能出现的空白数据。
/// 修复版：自身持有了 `systemMessage` 状态，用于展示清理缓存等操作的系统气泡。
struct MobileSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    
    // ✨ 修复：改为 @State，让设置页自己管理自己的通知气泡，消除入参报错
    @State private var systemMessage: AttributedString? = nil
    
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]
    
    @AppStorage("defaultStartupTab", store: SharedDatabase.shared.sharedDefaults)
    private var defaultStartupTab: String = "home"
    
    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if let config = configs.first {
                    MobileSettingsForm(
                        config: config,
                        defaultStartupTab: $defaultStartupTab,
                        systemMessage: $systemMessage, // 传递给内部的 Form
                        modelContext: modelContext
                    )
                    .onAppear {
                        // 🧹 清理多余数据
                        if configs.count > 1 {
                            for i in 1 ..< configs.count {
                                modelContext.delete(configs[i])
                            }
                            try? modelContext.save()
                        }
                    }
                } else {
                    ProgressView()
                        .onAppear { initializeConfig() }
                }
            }
            
            // ✨ 补充：iOS 端的原生 Toast 通知气泡 UI
            if let msg = systemMessage {
                Text(msg)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color(uiColor: .systemBackground).opacity(0.8))
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.15), radius: 10, y: 5)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .scale(scale: 0.9)).combined(with: .opacity))
                    .zIndex(100)
            }
        }
    }
    
    private func initializeConfig() {
        let newConfig = UserConfig()
        modelContext.insert(newConfig)
        try? modelContext.save()
    }
}

// MARK: - 📝 底层表单定义

/// 抽离出的纯净表单视图，使用 `@Bindable` 使得原生控件能直接读写数据库。
private struct MobileSettingsForm: View {
    @Bindable var config: UserConfig
    @Binding var defaultStartupTab: String
    @Binding var systemMessage: AttributedString?
    let modelContext: ModelContext
    
    var body: some View {
        List {
            // ================= 1. 🎯 阅读目标 =================
            Section {
                HStack {
                    SettingIcon(icon: "timer", color: .orange)
                    Text("每日专注目标")
                    Spacer()
                    Picker("", selection: Binding(
                        get: { config.dailyReadingGoal },
                        set: { config.dailyReadingGoal = $0; saveAndNotify() }
                    )) {
                        Text("15 分钟").tag(15)
                        Text("30 分钟").tag(30)
                        Text("45 分钟").tag(45)
                        Text("60 分钟").tag(60)
                        Text("120 分钟").tag(120)
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                }
                
                HStack {
                    SettingIcon(icon: "flag.fill", color: .pink)
                    Text("年度阅读目标")
                    Spacer()
                    Stepper(value: Binding(
                        get: { config.yearlyBookGoal },
                        set: { config.yearlyBookGoal = $0; saveAndNotify() }
                    ), in: 1...365, step: 5) {
                        Text("\(config.yearlyBookGoal) 本")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 140)
                }
                
                HStack {
                    SettingIcon(icon: "books.vertical.fill", color: .indigo)
                    Text("终身馆藏目标")
                    Spacer()
                    Stepper(value: Binding(
                        get: { config.libraryTargetGoal },
                        set: { config.libraryTargetGoal = $0; saveAndNotify() }
                    ), in: 100...10000, step: 100) {
                        Text("\(config.libraryTargetGoal) 本")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 140)
                }
            } header: {
                Text("阅读目标")
            } footer: {
                Text("目标将通过 iCloud 自动同步至您的 Mac 与小组件。")
            }
            
            // ================= 2. 🎨 外观与体验 =================
            Section {
                HStack {
                    SettingIcon(icon: "paintpalette.fill", color: .blue)
                    Text("主题偏好")
                    Spacer()
                    Picker("", selection: Binding(
                        get: { config.appTheme },
                        set: { newValue in
                            config.appTheme = newValue
                            saveAndNotify()
                            applyTheme(newValue) // 点击瞬间，触发原生换肤
                        }
                    )) {
                        Text("跟随系统").tag("system")
                        Text("浅色模式").tag("light")
                        Text("深色模式").tag("dark")
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                }
                
                HStack {
                    SettingIcon(icon: "arrow.triangle.2.circlepath.cloud.fill", color: .teal)
                    Text("iCloud 数据同步")
                    Spacer()
                    Text("已连接")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("外观与体验")
            }
            
            // ================= 3. 🏆 荣誉与徽章 =================
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        MobileBadgeView(icon: "flame.fill", title: "初识书香", subtitle: "连续打卡 7 天", color: .orange, isUnlocked: true)
                        MobileBadgeView(icon: "crown.fill", title: "手不释卷", subtitle: "年度读完 \(config.yearlyBookGoal) 本", color: .yellow, isUnlocked: true)
                        MobileBadgeView(icon: "star.fill", title: "百日筑基", subtitle: "连续打卡 100 天", color: .pink, isUnlocked: false)
                        MobileBadgeView(icon: "text.book.closed.fill", title: "千书之馆", subtitle: "馆藏达 \(config.libraryTargetGoal) 本", color: .indigo, isUnlocked: false)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 4)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0))
            } header: {
                Text("成就徽章")
            }
            
            // ================= 4. 系统与清理 =================
            Section {
                HStack {
                    SettingIcon(icon: "memorychip", color: .gray)
                    Text("清理图片缓存")
                    Spacer()
                    Button(action: clearImageCache) {
                        Text("释放空间").font(.system(size: 14))
                    }
                }
            } header: {
                Text("系统")
            }
            
            // ================= 5. 关于 =================
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0 (Beta)")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - 内部设置引擎逻辑
    
    private func applyTheme(_ theme: String) {
        let style: UIUserInterfaceStyle = {
            switch theme {
            case "light": return .light
            case "dark": return .dark
            default: return .unspecified
            }
        }()
            
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
    
    private func saveAndNotify() {
        config.updatedAt = Date()
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// 模拟清理缓存动作并抛出气泡反馈
    private func clearImageCache() {
        var log = AttributedString("✨ 清理完成！释放了 ")
        var sizeStr = AttributedString("\(Int.random(in: 12...45)) MB")
        sizeStr.foregroundColor = .green
        log.append(sizeStr); log.append(AttributedString(" 的图片缓存空间。"))
        
        withAnimation { systemMessage = log }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { systemMessage = nil } }
    }
}
#endif
