#if os(macOS)
import SwiftUI

// ============================================================================
// MARK: - 🧰 第一部分：工具栏原子组件 (Toolbar Items)
// ============================================================================

struct NativeSearchBar: NSViewRepresentable {
    @Binding var text: String
    @Binding var isActive: Bool
    
    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.placeholderString = "搜索"
        searchField.delegate = context.coordinator
        searchField.focusRingType = .default
        
        DispatchQueue.main.async {
            searchField.window?.makeFirstResponder(searchField)
        }
        return searchField
    }
    
    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isActive: $isActive)
    }
    
    class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String
        @Binding var isActive: Bool
        
        init(text: Binding<String>, isActive: Binding<Bool>) {
            self._text = text
            self._isActive = isActive
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSSearchField {
                text = field.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                text = ""
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isActive = false
                }
                return true
            }
            return false
        }
    }
}

// MARK: - ✨ 纯正原生版：无闪烁丝滑伸缩全局搜索组件

struct ExpandableSearchItem: View {
    @Binding var searchText: String
    @Binding var isActive: Bool
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // 1. 底层图标按钮（收起时显示，展开时稍微往左退让并隐身）
            SearchToggleButton(isSearchActive: $isActive)
                .offset(x: isActive ? -12 : 0)
                .opacity(isActive ? 0.0 : 1.0)
                // 防止看不见的时候阻挡鼠标点击
                .allowsHitTesting(!isActive)
            
            // 2. 搜索框罩在上方
            NativeSearchBar(text: $searchText, isActive: $isActive)
                // ✨ 绝杀 1：直接驱动搜索框自身的真实物理宽度变化！绝不让它拖着 180 的残躯乱跑。
                .frame(width: isActive ? 180 : 32)
                .opacity(isActive ? 1.0 : 0.0)
                // ✨ 绝杀 2：关闭的瞬间立刻禁用交互！这会强制 macOS 底层瞬间销毁蓝色的 Focus Ring！
                .disabled(!isActive)
        }
        // ❌ 绝对不能在这里加 .frame()，让 ZStack 像流水一样自然包裹内部尺寸！
        .animation(.appSnappy, value: isActive)
    }
}



/// 1. 统一排序菜单按钮
/// 支持传入任意遵守 Identifiable 和 RawRepresentable 的枚举（如 GallerySortType）
struct SortMenuButton<T: Identifiable & Hashable & RawRepresentable>: View where T.RawValue == String {
    @Binding var selection: T
    let options: [T]
    
    var body: some View {
        Menu {
            // ✨ 规范化：使用系统原生 Picker，系统会自动在选中的项旁边打勾
            Picker("排序方式", selection: $selection) {
                ForEach(options) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Image(systemName: "arrow.up.arrow.down").font(.system(size: 16, weight: .medium))
        }
        .menuIndicator(.hidden)
        .help("排序方式")
    }
}
/// 2. 状态/分类筛选菜单按钮
/// 支持灵活传入当前选中的 String 或 Enum 标签，以及动态的 Icon
struct FilterMenuButton<T: Hashable & CustomStringConvertible>: View {
    @Binding var selection: T
    let options: [T]
    let activeIcon: String
    let inactiveIcon: String
    let isFiltered: Bool
    
    var body: some View {
        Menu {
            // ✨ 规范化：统一使用 Picker
            Picker("分类筛选", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option.description).tag(option)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Image(systemName: isFiltered ? activeIcon : inactiveIcon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isFiltered ? .accentColor : .primary)
        }
        .menuIndicator(.hidden)
        .help("分类筛选")
    }
}

/// 3. 网格视图缩放菜单按钮
struct GridScaleMenuButton: View {
    @Binding var scaleIndex: Double
    
    var body: some View {
        Menu {
            Button(action: { scaleIndex = 0.0 }) { if scaleIndex == 0.0 { Label("小视图", systemImage: "checkmark") } else { Text("小视图") } }
            Button(action: { scaleIndex = 1.0 }) { if scaleIndex == 1.0 { Label("中等视图", systemImage: "checkmark") } else { Text("中等视图") } }
            Button(action: { scaleIndex = 2.0 }) { if scaleIndex == 2.0 { Label("默认视图", systemImage: "checkmark") } else { Text("默认视图") } }
            Button(action: { scaleIndex = 3.0 }) { if scaleIndex == 3.0 { Label("大视图", systemImage: "checkmark") } else { Text("大视图") } }
        } label: {
            Image(systemName: "square.grid.2x2").font(.system(size: 16, weight: .medium))
        }
        .menuIndicator(.hidden)
        .help("网格大小")
    }
}

/// 4. 漫游模式菜单按钮 (灵感画廊专用)
struct RoamModeMenuButton: View {
    @Binding var isRandom: Bool
    let onShuffle: () -> Void
    
    var body: some View {
        Menu {
            Button(action: { isRandom = false }) {
                HStack { Text("书籍分类"); if !isRandom { Image(systemName: "checkmark") } }
            }
            Button(action: { isRandom = true; onShuffle() }) {
                HStack { Text("随机漫游"); if isRandom { Image(systemName: "checkmark") } }
            }
        } label: {
            Image(systemName: isRandom ? "shuffle" : "folder")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isRandom ? .blue : .primary)
        }
        .menuIndicator(.hidden)
        .help("漫游模式")
    }
}

/// 5. 批量管理开关按钮
struct BatchEditToggleButton: View {
    @Binding var isEditing: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            Image(systemName: isEditing ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isEditing ? .blue : .primary)
        }
        .help("批量管理")
    }
}

/// 6. 搜索唤醒按钮
struct SearchToggleButton: View {
    @Binding var isSearchActive: Bool
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isSearchActive = true }
        }) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
        }
        .help("搜索")
    }
}

/// 7. 年度选择器菜单 (年度轨迹专用)
struct YearSelectorMenuButton: View {
    @Binding var selectedYear: Int
    let availableYears: [Int]
    let onSelect: (Int) -> Void
    
    var body: some View {
        Menu {
            // ✨ 规范化：使用原生 Picker 取代普通 Button，获得选择状态的原生 UI 质感
            Picker("选择年份", selection: Binding(
                get: { selectedYear },
                set: { newValue in
                    selectedYear = newValue
                    onSelect(newValue)
                }
            )) {
                ForEach(availableYears, id: \.self) { year in
                    Text("\(String(year)) 年").tag(year)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            // ✨ 规范化：去掉了 padding、颜色硬编码和 borderlessButton 修饰，
            // 现在的外观将与其他图标按钮完全处于同一水平线！
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text("\(String(selectedYear))")
            }
            .font(.system(size: 16, weight: .medium))
        }
        .menuIndicator(.hidden)
        .help("切换回顾年份")
    }
}

/// 8. 实体管理操作组 (详情页的编辑/删除)
struct EntityActionToolbarGroup: ToolbarContent {
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .help("编辑信息")
            
            Button(action: onDelete) {
                Image(systemName: "trash").foregroundStyle(Color.red)
            }
            .help("彻底删除")
        }
    }
}

/// ✨ 9. 显示模式切换按钮 (画廊 / 瀑布流)
struct DisplayModeToggleButton: View {
    @Binding var isCarousel: Bool
    
    var body: some View {
        Button(action: {
            withAnimation(.appFluidSpring) { isCarousel.toggle() }
        }) {
            Image(systemName: isCarousel ? "rectangle.grid.2x2" : "rectangle.stack")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
        .help(isCarousel ? "切换为多列瀑布流" : "切换为横向画廊视图")
    }
}

// ============================================================================
// MARK: - 🚀 第二部分：页面级动作按钮 (Page Action Buttons)
// ============================================================================

/// 统一的高亮大按钮组件 (用于添加笔记、添加摘录、完成管理等)
struct ProminentActionButton: View {
    let title: String
    let systemImage: String
    let tintColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.borderedProminent)
        .tint(tintColor)
        .controlSize(.large)
    }
}

/// 全局通用的返回按钮
struct GlobalBackButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
            Text("返回")
        }
    }
}

/// 全局通用的图书导入按钮
struct GlobalAddBookButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
        }
        .help("搜索并导入图书 (⌘N)")
    }
}
#endif
