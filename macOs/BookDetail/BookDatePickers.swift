#if os(macOS)
import SwiftUI
import SwiftData

// MARK: - ✨ 高级日期选择器矩阵

/// 渲染书籍起止时间并计算历时的主控组件。
///
/// 内部聚合了极其复杂的 iOS 拟物风格自定义弹出式日历 (`ScreenshotStyleDatePicker`)。
struct BookDatePickers: View {
    @Bindable var book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("阅读旅程", systemImage: "calendar")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.mint)
            
            HStack(spacing: 16) {
                if book.status == .unread {
                    Text("等待翻开第一页...")
                        .font(.system(size: 14, weight: .medium, design: .serif)).italic()
                        .foregroundColor(.secondary)
                        .frame(minHeight: 36)
                    Spacer()
                } else {
                    AdvancedDatePickerButton(icon: "play.fill", title: "开始", date: $book.startTime)
                    AdvancedDatePickerButton(icon: "flag.fill", title: "结束", date: $book.endTime, isDisabled: book.status != .finished)
                    
                    if book.status == .finished, let start = book.startTime, let end = book.endTime {
                        let diff = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start), to: Calendar.current.startOfDay(for: end)).day ?? 0
                        let days = max(1, diff + 1)
                        
                        HStack {
                            Text("历时").font(.system(size: 14, weight: .bold)).foregroundColor(.secondary)
                            Spacer()
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(days)").font(.system(size: 18, weight: .black, design: .rounded)).foregroundColor(.mint)
                                Text("天").font(.system(size: 12, weight: .bold)).foregroundColor(.mint)
                            }
                        }
                        .frame(width: 90).padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
                        .transition(.scale.combined(with: .opacity))
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
        }
    }
}

/// 承载悬停效果与点击弹出气泡事件的触发器按钮。
struct AdvancedDatePickerButton: View {
    let icon: String; let title: String; @Binding var date: Date?; var isDisabled: Bool = false
    @State private var isShowingPopover = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isShowingPopover.toggle() }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(date != nil ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1)).frame(width: 36, height: 36)
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(date != nil ? .blue : .secondary)
                }
                
                HStack(spacing: 10) {
                    Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                    if let d = date {
                        Text(d.formatted(date: .numeric, time: .omitted)).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.primary)
                    } else {
                        Text("尚未设置").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.secondary.opacity(0.6))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity)
            .background(isHovered ? Color.secondary.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain).disabled(isDisabled).opacity(isDisabled ? 0.4 : 1.0)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.2)) { isHovered = h }
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .popover(isPresented: $isShowingPopover, arrowEdge: Edge.bottom) {
            ScreenshotStyleDatePicker(selectedDate: $date)
        }
    }
}

/// 深度定制的弹出式日历模块，完美模拟 iOS 的图形化操作体验。
private struct ScreenshotStyleDatePicker: View {
    @Binding var selectedDate: Date?
    var customCalendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // 强制周一作为每周第一天
        return cal
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Spacer()
                Capsule().fill(Color.blue).frame(width: 3, height: 14)
                Text("时间").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary)
                Spacer()
            }.padding(.top, 16).padding(.bottom, 4)
            
            QuickOptionRow(icon: "star.fill", iconColor: .yellow, title: "今天", isSelected: isToday(selectedDate)) { selectedDate = Date() }
            Divider().padding(.vertical, 8).padding(.horizontal, 16)
            
            DatePicker("", selection: Binding(get: { selectedDate ?? Date() }, set: { selectedDate = $0 }), displayedComponents: .date)
                .datePickerStyle(.graphical).labelsHidden()
                .environment(\.calendar, customCalendar)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                // 放大原生空间以增加触控热区
                .scaleEffect(1.5)
                .frame(width: 250, height: 260).padding(.horizontal, 24).padding(.bottom, 20)
        }
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func isToday(_ date: Date?) -> Bool {
        guard let date = date else { return false }
        return Calendar.current.isDateInToday(date)
    }
}

/// 日历弹出框内辅助的一键直达按钮 (如：选为"今天")。
private struct QuickOptionRow: View {
    let icon: String; let iconColor: Color; let title: String; let isSelected: Bool; let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(iconColor).frame(width: 20)
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                if isSelected { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundColor(.blue) }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(isHovered ? Color.secondary.opacity(0.1) : Color.clear).cornerRadius(8).padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .onHover { h in isHovered = h; if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
    }
}
#endif
