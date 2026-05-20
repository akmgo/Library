#if os(iOS)
import SwiftUI
import SwiftData
import WidgetKit

// MARK: - ⚙️ iOS 端偏好设置主路由容器

struct MobileSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \UserConfig.updatedAt, order: .reverse) var configs: [UserConfig]
    
    /// 全局浮窗通知绑定变量
    @State private var systemMessage: AttributedString? = nil
    
    // 提取到主页的常规设置与目标保存防抖
    @AppStorage("appTheme", store: SharedDatabase.shared.sharedDefaults) private var appTheme: String = "system"
    @State private var saveTask: Task<Void, Never>? = nil
    
    // 用于控制关闭弹窗
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                if let config = configs.first {
                    Form {
                        // ================= 1. 外观主题 (平铺展开) =================
                        Section(header: Text("外观主题")) {
                            Picker("外观主题", selection: $appTheme) {
                                Text("跟随系统").tag("system")
                                Text("浅色模式").tag("light")
                                Text("深色模式").tag("dark")
                            }
                            .pickerStyle(.segmented)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        
                        // ================= 2. 阅读目标 (平铺展开，左右布局) =================
                        Section(header: Text("阅读目标")) {
                            MobileGoalRow(icon: "timer", iconColor: .orange, title: "每日阅读目标", subtitle: "每天期望达成的沉浸阅读时长（分钟）") {
                                MobileFluidCapsuleStepper(value: Binding(get: { config.dailyMinutesGoal }, set: { config.dailyMinutesGoal = $0 }), step: 5, range: 5...120, action: saveConfig)
                            }
                            
                            MobileGoalRow(icon: "target", iconColor: .pink, title: "年度阅读目标", subtitle: "今年计划通关的书籍数量（本）") {
                                MobileFluidCapsuleStepper(value: Binding(get: { config.yearlyBooksGoal }, set: { config.yearlyBooksGoal = $0 }), step: 1, range: 1...500, action: saveConfig)
                            }
                            
                            MobileGoalRow(icon: "archivebox.fill", iconColor: .teal, title: "总馆藏目标", subtitle: "期望打造的个人书库规模（本）") {
                                MobileFluidCapsuleStepper(value: Binding(get: { config.libraryBooksGoal }, set: { config.libraryBooksGoal = $0 }), step: 10, range: 10...999_999, action: saveConfig)
                            }
                        }
                        
                        // ================= 3. 高级设置子路由 =================
                        Section {
                            NavigationLink {
                                MobileDataSettingsView(systemMessage: $systemMessage)
                            } label: {
                                SettingsHeaderRow(icon: "externaldrive.fill", iconColor: .blue, title: "数据与安全", subtitle: "iCloud 同步、本地快照与缓存")
                            }
                            
                            NavigationLink {
                                MobileAboutSettingsView()
                            } label: {
                                SettingsHeaderRow(icon: "info.circle.fill", iconColor: .indigo, title: "关于 MyLibrary", subtitle: "版本信息与开发者联系方式")
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(AppColors.primaryBackground(for: colorScheme))
                    .onAppear {
                        // 数据自愈：清理多余的配置实体
                        if configs.count > 1 {
                            for i in 1 ..< configs.count { modelContext.delete(configs[i]) }
                            try? modelContext.save()
                        }
                    }
                } else {
                    VStack {
                        ProgressView()
                        Text("初始化配置中...").font(.caption).foregroundColor(.secondary).padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.primaryBackground(for: colorScheme))
                    .onAppear { initializeConfig() }
                }
                
                // ================= 动态顶置通知胶囊 =================
                if let msg = systemMessage {
                    Text(msg)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppColors.secondaryBackground(for: colorScheme).opacity(0.9))
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.15), radius: 10, y: 5)
                        .padding(.top, 16)
                        .transition(.move(edge: .top).combined(with: .scale(scale: 0.9)).combined(with: .opacity))
                        .zIndex(100)
                }
            }
            .navigationTitle("系统设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }) {
                        Text("完成").font(.system(size: 16, weight: .bold))
                    }
                }
            }
        }
    }
    
    private func initializeConfig() {
        let newConfig = UserConfig()
        modelContext.insert(newConfig)
        try? modelContext.save()
    }
    
    private func saveConfig() {
        saveTask?.cancel()
        saveTask = Task {
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    if let config = configs.first {
                        config.updatedAt = Date()
                        try? modelContext.save()
                        WidgetCenter.shared.reloadAllTimelines()
                        showToast("✅ 目标数据已保存")
                    }
                }
            } catch {}
        }
    }
    
    private func showToast(_ msg: String) {
        withAnimation { systemMessage = AttributedString(msg) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { systemMessage = nil } }
    }
}

// MARK: - UI 原子组件 (✨ 顶级对齐优化版)

/// 主页子路由导航行
struct SettingsHeaderRow: View {
    let icon: String; let iconColor: Color; let title: String; let subtitle: String
    var body: some View {
        // ✨ 强制顶部对齐
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(iconColor).frame(width: 30, height: 30)
                Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
            }
            .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(.primary)
                Text(subtitle).font(.system(size: 12)).foregroundColor(.secondary).lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

/// 专为阅读目标设计的左右弹性布局行
struct MobileGoalRow<Content: View>: View {
    let icon: String; let iconColor: Color; let title: String; let subtitle: String; @ViewBuilder let control: Content
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // 左侧：图标与文字采用顶部对齐的内嵌 HStack
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(iconColor).frame(width: 28, height: 28)
                    Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                }
                .padding(.top, 2) // ✨ 视觉微调
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
                    Text(subtitle).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(2) // 支持两行
                }
            }
            
            Spacer(minLength: 8)
            
            // 右侧：保留传入的控制组件，并整体保持居中对齐
            control
        }
        .padding(.vertical, 6)
    }
}

/// 调整了按钮体积以适应右侧布局的流体增减器 (保持原样不变)
private struct MobileFluidCapsuleStepper: View {
    @Binding var value: Int; let step: Int; let range: ClosedRange<Int>; let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                if value > range.lowerBound {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(); value = max(range.lowerBound, value - step); action()
                }
            }) { Image(systemName: "minus").font(.system(size: 14, weight: .bold)).frame(width: 36, height: 30).contentShape(Rectangle()) }
            .buttonStyle(.plain).disabled(value <= range.lowerBound).opacity(value <= range.lowerBound ? 0.3 : 1.0)
            
            Text("\(value)").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.primary).frame(width: 48).multilineTextAlignment(.center)
            
            Button(action: {
                if value < range.upperBound {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(); value = min(range.upperBound, value + step); action()
                }
            }) { Image(systemName: "plus").font(.system(size: 14, weight: .bold)).frame(width: 36, height: 30).contentShape(Rectangle()) }
            .buttonStyle(.plain).disabled(value >= range.upperBound).opacity(value >= range.upperBound ? 0.3 : 1.0)
        }
        .background(AppColors.tertiaryBackground(for: colorScheme)).clipShape(Capsule()).overlay(Capsule().stroke(Color.secondary.opacity(0.1), lineWidth: 1))
    }
}

struct MobileSettingsControlRow<Content: View>: View {
    let icon: String; let iconColor: Color; let title: String; let subtitle: String; @ViewBuilder let control: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ✨ 强制顶部对齐
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(iconColor).frame(width: 28, height: 28)
                    Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                }
                .padding(.top, 2) // ✨ 视觉微调
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(.secondary).lineLimit(2)
                }
                
                Spacer(minLength: 16)
            }
            HStack { Spacer(); control }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - ℹ️ 关于页面 (保持原样不变)
struct MobileAboutSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0" }
    private var buildNumber: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1" }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous).fill(LinearGradient(colors: [.indigo, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 140, height: 140).shadow(color: .indigo.opacity(0.3), radius: 20, y: 10)
                Image(systemName: "books.vertical.fill").font(.system(size: 60)).foregroundColor(.white)
            }
            VStack(spacing: 8) {
                Text("MyLibrary").font(.system(size: 32, weight: .heavy, design: .rounded)).foregroundColor(.primary)
                Text("Version \(appVersion) (\(buildNumber))").font(.system(size: 14, design: .monospaced)).foregroundColor(.secondary)
                Text("构建属于你自己的纯粹阅读资产库").font(.system(size: 15, weight: .medium)).foregroundColor(.secondary.opacity(0.8)).padding(.top, 4)
            }
            Spacer()
            VStack(spacing: 20) {
                Button(action: { if let url = URL(string: "https://akram.top") { UIApplication.shared.open(url) } }) {
                    HStack { Image(systemName: "globe"); Text("访问开发者主页") }
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.white).frame(width: 240, height: 50).background(Color.blue).clipShape(Capsule())
                }
                Button(action: {
                    let subject = "MyLibrary 反馈与建议".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "mailto:akmgo2024@outlook.com?subject=\(subject)") { UIApplication.shared.open(url) }
                }) {
                    HStack { Image(systemName: "envelope.fill"); Text("通过邮件反馈") }
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.blue).frame(width: 240, height: 50).background(Color.blue.opacity(0.1)).clipShape(Capsule())
                }
            }
            Spacer()
            VStack(spacing: 4) {
                Text("Designed and Crafted by Akram").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary.opacity(0.6))
                Text("Copyright © \(String(Calendar.current.component(.year, from: Date()))) Akram. All rights reserved.").font(.system(size: 10)).foregroundColor(.secondary.opacity(0.5))
            }.padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.primaryBackground(for: colorScheme))
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
