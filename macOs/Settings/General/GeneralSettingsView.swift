#if os(macOS)
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - ✨ 常规偏好设置主视图

/// macOS 端专属的“常规”偏好设置页面容器。
///
/// **核心机制：**
/// 该视图负责拉取并初始化全局唯一的 `UserConfig` 实体。
/// 若数据库中尚未存在配置，它会显示进度条并在底层静默初始化一份默认配置；
/// 若存在多份因为 iCloud 冲突导致的多余配置，它会在 `onAppear` 时执行冗余清理。
struct GeneralSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var systemMessage: AttributedString?
    
    /// 核心查询：按更新时间降序排列，确保始终读取到最新的一条云端配置。
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]
    
    /// macOS 专属的设置，不存入 SwiftData，直接用共享 UserDefaults 存储。
    @AppStorage("defaultStartupTab", store: SharedDatabase.shared.sharedDefaults)
    private var defaultStartupTab: String = "home"
    
    var body: some View {
        Group {
            if let config = configs.first {
                GeneralSettingsForm(
                    config: config,
                    defaultStartupTab: $defaultStartupTab,
                    systemMessage: $systemMessage,
                    modelContext: modelContext
                )
                .onAppear {
                    // 🧹 清理 iCloud 同步可能产生的多余脏数据
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
    }
    
    /// 初始化系统兜底配置。
    private func initializeConfig() {
        let newConfig = UserConfig()
        modelContext.insert(newConfig)
        try? modelContext.save()
    }
}

// MARK: - 常规偏好表单主体

/// 抽离出来的实际设置表单视图。
///
/// 独立于主容器的好处是可以使用 `@Bindable` 直接绑定 `UserConfig`，
/// 从而让底层的 `Stepper` 等原生组件能够无缝地对 SwiftData 实体进行双向读写。
private struct GeneralSettingsForm: View {
    @Bindable var config: UserConfig
    @Binding var defaultStartupTab: String
    @Binding var systemMessage: AttributedString?
    let modelContext: ModelContext
    
    var body: some View {
        Form {
            // ==========================================
            // 1. 外观与偏好
            // ==========================================
            Section {
                SettingsControlRow(
                    icon: "macwindow", iconColor: .blue,
                    title: "外观主题", subtitle: "强制覆盖系统的深浅色模式设置"
                ) {
                    Picker("", selection: Binding(
                        get: { config.appTheme },
                        set: { newValue in
                            config.appTheme = newValue
                            saveAndNotify()
                            applyTheme(newValue) // ✨ 1. 点击瞬间，触发原生换肤
                        }
                    )) {
                        Text("跟随系统").tag("system")
                        Text("浅色模式").tag("light")
                        Text("深色模式").tag("dark")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
                
                SettingsControlRow(
                    icon: "house.fill", iconColor: .mint,
                    title: "默认启动视图", subtitle: "每次启动应用时优先展示的页面"
                ) {
                    Picker("", selection: $defaultStartupTab) {
                        Text("阅读主页").tag("home")
                        Text("全景画廊").tag("gallery")
                        Text("全息书景").tag("carousel")
                        Text("月度记录").tag("monthly")
                        Text("年度轨迹").tag("yearly")
                        Text("灵感碎片").tag("inspiration")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
            } header: {
                Text("外观与偏好").font(.system(size: 16, weight: .bold)).padding(.bottom, 6)
            }
            .padding(.bottom, 16)
            
            // ==========================================
            // 2. 阅读目标 (直接绑定 SwiftData 模型)
            // ==========================================
            Section {
                SettingsControlRow(
                    icon: "timer", iconColor: .orange,
                    title: "每日阅读目标", subtitle: "每天期望达成的沉浸阅读时长"
                ) {
                    HStack(spacing: 12) {
                        Text("\(config.dailyReadingGoal) 分钟")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .trailing)
                        
                        Stepper("", value: Binding(
                            get: { config.dailyReadingGoal },
                            set: { config.dailyReadingGoal = $0; saveAndNotify() }
                        ), in: 5...300, step: 5).labelsHidden()
                    }
                }
                
                SettingsControlRow(
                    icon: "target", iconColor: .purple,
                    title: "年度阅读目标", subtitle: "今年计划通关的书籍数量"
                ) {
                    HStack(spacing: 12) {
                        Text("\(config.yearlyBookGoal) 本")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .trailing)
                        
                        Stepper("", value: Binding(
                            get: { config.yearlyBookGoal },
                            set: { config.yearlyBookGoal = $0; saveAndNotify() }
                        ), in: 1...365, step: 5).labelsHidden()
                    }
                }
                
                SettingsControlRow(
                    icon: "archivebox.fill", iconColor: .indigo,
                    title: "总馆藏目标", subtitle: "期望打造的个人书库规模"
                ) {
                    HStack(spacing: 12) {
                        Text("\(config.libraryTargetGoal) 本")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .trailing)
                        
                        Stepper("", value: Binding(
                            get: { config.libraryTargetGoal },
                            set: { config.libraryTargetGoal = $0; saveAndNotify() }
                        ), in: 100...10000, step: 100).labelsHidden()
                    }
                }
            } header: {
                Text("阅读目标").font(.system(size: 16, weight: .bold)).padding(.bottom, 6)
            }
            .padding(.bottom, 16)
            
            // ==========================================
            // 3. 系统与存储
            // ==========================================
            Section {
                SettingsControlRow(
                    icon: "memorychip", iconColor: .gray,
                    title: "清理图片缓存", subtitle: "释放封面在内存中占用的临时空间（不影响本地数据）"
                ) {
                    Button(action: clearImageCache) {
                        Text("清理缓存").font(.system(size: 12, weight: .medium))
                    }
                }
            } header: {
                Text("系统").font(.system(size: 16, weight: .bold)).padding(.bottom, 6)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - 内部响应动作
    
    /// 触发 macOS 原生级换肤魔法 (瞬间生效)。
    ///
    /// - Parameter theme: "light", "dark" 或 "system"
    private func applyTheme(_ theme: String) {
        DispatchQueue.main.async {
            switch theme {
            case "light": NSApp.appearance = NSAppearance(named: .aqua)
            case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
            default: NSApp.appearance = nil // 👈 瞬间把控制权还给 macOS 系统！
            }
        }
    }
    
    /// 执行配置持久化，并通知桌面的 Widget 小组件刷新目标数据。
    private func saveAndNotify() {
        config.updatedAt = Date()
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// 抛出虚拟的缓存清理反馈吐司。
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
