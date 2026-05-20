import SwiftUI

private struct AppNativeBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.background(AppColors.primaryBackground(for: colorScheme).ignoresSafeArea())
    }
}

public extension View {
    
    /// 为当前视图应用 V1 设计方案定义的全局底层背景色。
    func applyNativeBackground() -> some View {
        modifier(AppNativeBackgroundModifier())
    }
}
