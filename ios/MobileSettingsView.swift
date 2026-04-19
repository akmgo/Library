#if os(iOS)
import SwiftData
import SwiftUI
import WidgetKit // 引入 WidgetKit 以便通知小组件刷新

struct MobileSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    /// ✨ 核心机制：按更新时间降序排列，永远把最新修改的配置顶在最前面
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]
    
    var body: some View {
        Group {
            if let config = configs.first {
                MobileSettingsForm(config: config)
                    .onAppear {
                        // 🧹 清理多余数据：如果 iCloud 意外同步过来了多条配置，删掉旧的，只留第一条
                        if configs.count > 1 {
                            for i in 1 ..< configs.count {
                                modelContext.delete(configs[i])
                            }
                            try? modelContext.save()
                        }
                    }
            } else {
                // 如果是新设备第一次打开，还没有配置，则初始化一条
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

/// 抽离出的表单视图，使用 @Bindable 直接绑定数据
private struct MobileSettingsForm: View {
    @Bindable var config: UserConfig
    @Environment(\.modelContext) private var modelContext
    
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
                            applyTheme(newValue) // ✨ 1. 点击瞬间，触发原生换肤
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
            
            // ================= 4. 关于 =================
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
    
    private func applyTheme(_ theme: String) {
        let style: UIUserInterfaceStyle = {
            switch theme {
            case "light": return .light
            case "dark": return .dark
            default: return .unspecified // 👈 瞬间把控制权还给 iOS 系统！
            }
        }()
            
        // 强行遍历所有窗口并应用
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
    
    /// ✨ 保存数据库并唤醒 Widget
    private func saveAndNotify() {
        config.updatedAt = Date()
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// 辅助组件：设置项统一图标
private struct SettingIcon: View {
    let icon: String
    let color: Color
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.gradient)
                .frame(width: 28, height: 28)
            
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.trailing, 4)
    }
}

/// 辅助组件：精美微型徽章
private struct MobileBadgeView: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? color.opacity(0.15) : Color.secondary.opacity(0.05))
                    .frame(width: 64, height: 64)
                Circle()
                    .fill(isUnlocked ? color.gradient : Color.secondary.opacity(0.1).gradient)
                    .frame(width: 48, height: 48)
                Image(systemName: isUnlocked ? icon : "lock.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isUnlocked ? .white : .secondary.opacity(0.4))
            }
            .shadow(color: isUnlocked ? color.opacity(0.3) : .clear, radius: 6, y: 3)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(isUnlocked ? .primary : .secondary)
                Text(subtitle)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .frame(width: 80)
        .grayscale(isUnlocked ? 0 : 1)
        .opacity(isUnlocked ? 1.0 : 0.6)
    }
}
#endif
