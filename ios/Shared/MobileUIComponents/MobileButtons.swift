#if os(iOS)
import SwiftUI

// ============================================================================
// MARK: - 🧰 iOS 工具栏原子组件 (Toolbar Items)
// ============================================================================

/// 1. 统一排序菜单按钮
/// 支持传入任意遵守 Identifiable 和 RawRepresentable 的枚举
struct MobileSortMenuButton<T: Identifiable & Hashable & RawRepresentable>: View where T.RawValue == String {
    @Binding var selection: T
    let options: [T]
    
    // ✨ iOS 专属扩展：支持传入升降序绑定，集成在同一个菜单中
    var isAscending: Binding<Bool>? = nil
    
    var body: some View {
        Menu {
            Picker("排序方式", selection: $selection) {
                ForEach(options) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            if let isAscending = isAscending {
                Divider()
                Toggle(isOn: isAscending) {
                    Label(isAscending.wrappedValue ? "升序排列" : "降序排列", systemImage: isAscending.wrappedValue ? "arrow.up" : "arrow.down")
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
                .font(.system(size: 20))
                .foregroundColor(.blue)
        }
    }
}

/// 2. 分类筛选菜单按钮 (纯净版)
struct MobileFilterMenuButton<T: Hashable & CustomStringConvertible>: View {
    @Binding var selection: T
    let options: [T]
    let activeIcon: String
    let inactiveIcon: String
    let isFiltered: Bool
    
    var body: some View {
        Menu {
            Picker("分类筛选", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option.description).tag(option)
                }
            }
        } label: {
            Image(systemName: isFiltered ? activeIcon : inactiveIcon)
                .font(.system(size: 20))
                .foregroundColor(isFiltered ? .blue : .primary)
        }
    }
}

/// 3. 显示模式切换按钮 (网格 / 画廊 / 列表)
struct MobileDisplayModeToggleButton: View {
    @Binding var isCarousel: Bool
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light); impact.impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isCarousel.toggle() }
        }) {
            Image(systemName: isCarousel ? "rectangle.grid.2x2" : "rectangle.stack")
                .font(.system(size: 20))
                .foregroundColor(.primary)
        }
    }
}

/// 4. 批量管理开关按钮
struct MobileBatchEditToggleButton: View {
    @Binding var isEditing: Bool
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium); impact.impactOccurred()
            withAnimation { isEditing.toggle() }
        }) {
            Image(systemName: isEditing ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.system(size: 20))
                .foregroundColor(isEditing ? .blue : .primary)
        }
    }
}

/// 5. 年度选择器菜单 (原生胶囊质感)
struct MobileYearSelectorMenuButton: View {
    @Binding var selectedYear: Int
    let availableYears: [Int]
    
    var body: some View {
        Menu {
            Picker("选择年份", selection: $selectedYear) {
                ForEach(availableYears, id: \.self) { year in
                    Text("\(String(year)) 年").tag(year)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text("\(String(selectedYear))")
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}

/// 6. 全局组件：漫游洗牌按钮
struct MobileShuffleButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: "shuffle")
                .font(.system(size: 18))
                .foregroundColor(.primary) // ✨ 统一去色，使用原生样式
        }
    }
}

/// 7. 全局组件：布局模式切换按钮 (分类 / 漫游)
struct MobileLayoutToggleButton: View {
    @Binding var isRandomRoam: Bool
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isRandomRoam.toggle()
            }
        }) {
            Image(systemName: isRandomRoam ? "rectangle.3.group.bubble.left" : "folder")
                .font(.system(size: 18))
                .foregroundColor(.primary) // ✨ 统一去色，使用原生样式
        }
    }
}

// ============================================================================
// MARK: - 🚀 第二部分：页面级动作按钮 (Page Action Buttons)
// ============================================================================

/// 统一的高亮大按钮组件 (常用于底部悬浮的“开始阅读”、“保存”等重级操作)
struct MobileProminentActionButton: View {
    let title: String
    let systemImage: String
    let tintColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(tintColor.gradient)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: tintColor.opacity(0.3), radius: 8, y: 4)
        }
    }
}
#endif
