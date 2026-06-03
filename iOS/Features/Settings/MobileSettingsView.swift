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
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                if let config = configs.first {
                    Form {
                        // ================= 1. 外观主题 (平铺展开) =================
                        Section(header: Text("外观主题")) {
                            AppSlidingSegmentedControl(
                                selection: $appTheme,
                                options: [
                                    AppSlidingSegmentedOption(value: "system", title: "系统", systemImage: "circle.lefthalf.filled"),
                                    AppSlidingSegmentedOption(value: "light", title: "浅色", systemImage: "sun.max.fill"),
                                    AppSlidingSegmentedOption(value: "dark", title: "深色", systemImage: "moon.fill"),
                                ],
                                height: 34,
                                cornerRadius: AppRadius.m
                            )
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        
                        // ================= 2. 阅读目标 (平铺展开，左右布局) =================
                        Section(header: Text("阅读目标")) {
                            SettingsRow(icon: "timer", iconColor: .orange, title: "每日阅读目标", subtitle: "每天期望达成的沉浸阅读时长（分钟）", titleSize: 15, subtitleSize: 11, subtitleLineLimit: 2) {
                                MobileFluidCapsuleStepper(value: Binding(get: { config.dailyMinutesGoal }, set: { config.dailyMinutesGoal = $0 }), step: 5, range: 5...120, action: saveConfig)
                            }
                            
                            SettingsRow(icon: "target", iconColor: .pink, title: "年度阅读目标", subtitle: "今年计划通关的书籍数量（本）", titleSize: 15, subtitleSize: 11, subtitleLineLimit: 2) {
                                MobileFluidCapsuleStepper(value: Binding(get: { config.yearlyBooksGoal }, set: { config.yearlyBooksGoal = $0 }), step: 1, range: 1...500, action: saveConfig)
                            }
                            
                            SettingsRow(icon: "archivebox.fill", iconColor: .teal, title: "总馆藏目标", subtitle: "期望打造的个人书库规模（本）", titleSize: 15, subtitleSize: 11, subtitleLineLimit: 2) {
                                MobileFluidCapsuleStepper(value: Binding(get: { config.libraryBooksGoal }, set: { config.libraryBooksGoal = $0 }), step: 10, range: 10...999_999, action: saveConfig)
                            }
                        }
                        
                        // ================= 3. 高级设置子路由 =================
                        Section {
                            NavigationLink {
                                MobileDataSettingsView(systemMessage: $systemMessage)
                            } label: {
                                SettingsRow(icon: "externaldrive.fill", iconColor: .blue, title: "数据与安全", subtitle: "iCloud 同步与缓存", iconSize: 30, titleSize: 16, subtitleSize: 12, subtitleLineLimit: 2)
                            }
                            
                            NavigationLink {
                                MobileAboutSettingsView()
                            } label: {
                                SettingsRow(icon: "info.circle.fill", iconColor: .indigo, title: "关于 MyLibrary", subtitle: "版本信息与开发者联系方式", iconSize: 30, titleSize: 16, subtitleSize: 12, subtitleLineLimit: 2)
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
                        Text("初始化配置中...").font(.caption).foregroundColor(.secondary).padding(.top, AppSpacing.xs)
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
                        .appCapsuleStyle(tint: AppColors.readingAmber, fillOpacity: 0.15, strokeOpacity: 0.10)
                        .padding(.top, AppSpacing.m)
                        .transition(.move(edge: .top).combined(with: .scale(scale: 0.9)).combined(with: .opacity))
                        .zIndex(100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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

/// 调整了按钮体积以适应右侧布局的流体增减器 (保持原样不变)
private struct MobileFluidCapsuleStepper: View {
    @Binding var value: Int; let step: Int; let range: ClosedRange<Int>; let action: () -> Void

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
        .appCapsuleStyle(tint: AppColors.readingAmber, fillOpacity: 0.12, strokeOpacity: 0.10)
    }
}

// MARK: - ℹ️ 关于页面 (保持原样不变)
struct MobileAboutSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0" }
    private var buildNumber: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1" }
    
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous).fill(LinearGradient(colors: [.indigo, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 140, height: 140).shadow(color: .indigo.opacity(0.3), radius: 20, y: 10)
                Image(systemName: "books.vertical.fill").font(.system(size: 60)).foregroundColor(.white)
            }
            VStack(spacing: AppSpacing.xs) {
                Text("MyLibrary").font(.system(size: 32, weight: .heavy, design: .rounded)).foregroundColor(.primary)
                Text("Version \(appVersion) (\(buildNumber))").font(.system(size: 14, design: .monospaced)).foregroundColor(.secondary)
                Text("构建属于你自己的纯粹阅读资产库").font(.system(size: 15, weight: .medium)).foregroundColor(.secondary.opacity(0.8)).padding(.top, 4)
            }
            Spacer()
            VStack(spacing: AppSpacing.l) {
                Button(action: { if let url = URL(string: "https://akram.top") { UIApplication.shared.open(url) } }) {
                    HStack { Image(systemName: "globe"); Text("访问开发者主页") }
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.blue).frame(width: 240, height: 50).appCapsuleStyle(tint: .blue)
                }
                Button(action: {
                    let subject = "MyLibrary 反馈与建议".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "mailto:akmgo2024@outlook.com?subject=\(subject)") { UIApplication.shared.open(url) }
                }) {
                    HStack { Image(systemName: "envelope.fill"); Text("通过邮件反馈") }
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.blue).frame(width: 240, height: 50).appCapsuleStyle(tint: .blue)
                }
            }
            Spacer()
            VStack(spacing: AppSpacing.xxs) {
                Text("Designed and Crafted by Akram").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary.opacity(0.6))
                Text("Copyright © \(String(Calendar.current.component(.year, from: Date()))) Akram. All rights reserved.").font(.system(size: 10)).foregroundColor(.secondary.opacity(0.5))
            }.padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.primaryBackground(for: colorScheme))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("设置页") {
    PreviewWithData {
        MobileSettingsView()
    }
}
#endif


#endif
