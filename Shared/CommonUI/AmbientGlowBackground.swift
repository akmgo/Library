import SwiftData
import SwiftUI

// MARK: - 跨平台公用背景

/// 兼容旧调用点的跨平台背景组件。V1 不再使用封面光晕或流动背景，只输出设计方案定义的底色。
struct AmbientGlowBackground: View {
    let book: Book?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        AppColors.primaryBackground(for: colorScheme)
            .ignoresSafeArea()
    }
}
