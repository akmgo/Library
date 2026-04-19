import SwiftUI

public extension View {
    /// 纯正的苹果原生底层背景色
    func applyNativeBackground() -> some View {
        #if os(macOS)
        self.background(Color(NSColor.windowBackgroundColor).ignoresSafeArea())
        #else
        // systemGroupedBackground 是 iOS 专为卡片式布局设计的原生大背景色 (浅色模式下是极浅的灰，深色模式下是纯黑)
        self.background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        #endif
    }
}
