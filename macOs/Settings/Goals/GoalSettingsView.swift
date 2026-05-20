#if os(macOS)
import SwiftData
import SwiftUI
import WidgetKit
import AppKit

struct GoalSettingsView: View {
    @Bindable var config: UserConfig
    @Binding var systemMessage: AttributedString?
    @Environment(\.modelContext) private var modelContext
    
    /// 用来保存当前正在倒计时的任务 (防抖引擎)
    @State private var saveTask: Task<Void, Never>? = nil
    
    var body: some View {
        Form {
            Section {
                // 1. 每日阅读目标 (5~120，步长5)
                // ✨ 优化：单位转移至 subtitle，右侧仅保留纯净的控制舱
                SettingsControlRow(icon: "timer", iconColor: .orange, title: "每日阅读目标", subtitle: "每天期望达成的沉浸阅读时长（分钟）") {
                    FluidCapsuleStepper(
                        value: Binding(get: { config.dailyMinutesGoal }, set: { config.dailyMinutesGoal = $0 }),
                        step: 5,
                        range: 5...120,
                        action: saveConfig
                    )
                }
                
                // 2. 年度阅读目标 (1~500，步长1)
                SettingsControlRow(icon: "target", iconColor: .pink, title: "年度阅读目标", subtitle: "今年计划通关的书籍数量（本）") {
                    FluidCapsuleStepper(
                        value: Binding(get: { config.yearlyBooksGoal }, set: { config.yearlyBooksGoal = $0 }),
                        step: 1,
                        range: 1...500,
                        action: saveConfig
                    )
                }
                
                // 3. 总馆藏目标 (10~无限制，步长10)
                SettingsControlRow(icon: "archivebox.fill", iconColor: .teal, title: "总馆藏目标", subtitle: "期望打造的个人书库规模（本）") {
                    FluidCapsuleStepper(
                        value: Binding(get: { config.libraryBooksGoal }, set: { config.libraryBooksGoal = $0 }),
                        step: 10,
                        range: 10...999_999,
                        action: saveConfig
                    )
                }
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - 💾 防抖保存引擎
    private func saveConfig() {
        saveTask?.cancel()
        saveTask = Task {
            do {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒防抖
                await MainActor.run {
                    config.updatedAt = Date()
                    try? modelContext.save()
                    WidgetCenter.shared.reloadAllTimelines()
                    print("✅ 目标数据已保存，小组件已刷新")
                }
            } catch {
                // 任务被取消，什么都不做
            }
        }
    }
}

// MARK: - 🎨 方案 A 组件：流体胶囊 (绝对对齐统一宽度版)
private struct FluidCapsuleStepper: View {
    @Binding var value: Int
    let step: Int
    let range: ClosedRange<Int>
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                if value > range.lowerBound {
                    value = max(range.lowerBound, value - step)
                    action()
                }
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .bold))
                    // 固定左侧按钮宽度
                    .frame(width: 28, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(value <= range.lowerBound) // 触底禁用
            .opacity(value <= range.lowerBound ? 0.3 : 1.0)
            
            Text("\(value)")
                // ✨ 优化：去除了 weight: .heavy / .bold，恢复为常规等宽体，视觉更轻盈
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.primary)
                // ✨ 核心修复：锁死纯数字显示区的绝对宽度，足以容纳 "999999" 六位数
                .frame(width: 56)
                .multilineTextAlignment(.center)
            
            Button(action: {
                if value < range.upperBound {
                    value = min(range.upperBound, value + step)
                    action()
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    // 固定右侧按钮宽度
                    .frame(width: 28, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(value >= range.upperBound) // 触顶禁用
            .opacity(value >= range.upperBound ? 0.3 : 1.0)
        }
        // 整体宽度被绝对固定为：28 + 56 + 28 = 112
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.secondary.opacity(0.1), lineWidth: 1))
    }
}

#endif
