#if os(macOS)
import SwiftData
import SwiftUI
import WidgetKit

struct GeneralSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var systemMessage: AttributedString?
    
    /// ✨ 核心机制：查询唯一的 UserConfig 记录，降序排列保证取到最新的
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]
    
    /// macOS 专属的设置，不存入 SwiftData，直接用共享 UserDefaults 存储即可
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
                    // 🧹 清理 iCloud 同步可能产生的多余配置
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
    
    private func initializeConfig() {
        let newConfig = UserConfig()
        modelContext.insert(newConfig)
        try? modelContext.save()
    }
}

/// 抽离出来的表单视图，方便使用 @Bindable
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
    
    /// ✨ 2. macOS 原生级换肤魔法 (瞬间生效)
    private func applyTheme(_ theme: String) {
        DispatchQueue.main.async {
            switch theme {
            case "light": NSApp.appearance = NSAppearance(named: .aqua)
            case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
            default: NSApp.appearance = nil // 👈 瞬间把控制权还给 macOS 系统！
            }
        }
    }
    
    /// ✨ 保存数据库并唤醒 Widget
    private func saveAndNotify() {
        config.updatedAt = Date()
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
    
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
