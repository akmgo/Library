import SwiftUI

public extension View {
    
    /// 为当前视图应用纯正的苹果原生底层背景色。
    ///
    /// 这是一个视图修饰符扩展。它会自动判断当前编译的操作系统，并应用最适合作为底层卡片容器的背景色：
    /// - 在 **iOS** 上，使用 `systemGroupedBackground`（浅色模式下为浅灰，深色模式下为纯黑），这是 iOS 设计规范中标准的底层色彩。
    /// - 在 **macOS** 上，使用 `windowBackgroundColor`，完美契合 Mac 窗口的磨砂质感。
    ///
    /// - Returns: 返回应用了原生背景色并忽略安全区域限制的 View。
    func applyNativeBackground() -> some View {
        #if os(macOS)
        self.background(Color(NSColor.windowBackgroundColor).ignoresSafeArea())
        #else
        // systemGroupedBackground 是 iOS 专为卡片式布局设计的原生大背景色 (浅色模式下是极浅的灰，深色模式下是纯黑)
        self.background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        #endif
    }
}
