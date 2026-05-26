#if os(macOS) || os(iOS)
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct AppSlidingSegmentedOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    let systemImage: String?

    var id: Value { value }

    init(value: Value, title: String, systemImage: String? = nil) {
        self.value = value
        self.title = title
        self.systemImage = systemImage
    }
}

struct AppSlidingSegmentedControl<Value: Hashable>: View {
    @Binding var selection: Value

    let options: [AppSlidingSegmentedOption<Value>]
    var tint: Color = AppColors.selection
    var height: CGFloat = 36
    var cornerRadius: CGFloat = AppRadius.m
    var selectedForeground: Color = .white
    var unselectedForeground: Color = .primary.opacity(0.72)
    var showsIcons = true

    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                segment(for: option)
            }
        }
        .padding(4)
        .appInnerBlockStyle(cornerRadius: cornerRadius)
    }

    private func segment(for option: AppSlidingSegmentedOption<Value>) -> some View {
        let isSelected = selection == option.value

        return Button {
            guard selection != option.value else { return }
            performSelectionFeedback()
            withAnimation(.easeOut(duration: 0.16)) {
                selection = option.value
            }
        } label: {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: max(cornerRadius - 4, AppRadius.xs), style: .continuous)
                        .fill(tint)
                        .matchedGeometryEffect(id: "app-sliding-segment-selection", in: selectionNamespace)
                }

                HStack(spacing: 6) {
                    if showsIcons, let systemImage = option.systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 11, weight: .semibold))
                    }

                    Text(option.title)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                }
                .foregroundStyle(isSelected ? selectedForeground : unselectedForeground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func performSelectionFeedback() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
#endif
