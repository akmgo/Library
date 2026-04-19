import SwiftData
import SwiftUI

// MARK: - ✨ 跨平台公用组件：全息环境氛围光
struct AmbientGlowBackground: View {
    let book: Book?
    
    var body: some View {
        ZStack {
            // 1. 跨平台底层系统底色
            #if os(iOS)
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            #else
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            #endif
            
            // 2. 封面全屏极度模糊放大
            if let book = book {
                GeometryReader { geo in
                    LocalCoverView(coverData: book.coverData, fallbackTitle: "")
                        .scaledToFill()
                        // 强制宽高匹配当前屏幕
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 80) // 极致毛玻璃
                        .scaleEffect(1.5) // 放大推掉边缘切割感
                        .opacity(0.4)     // 隐约透出色彩
                        // 绝对居中锚定
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: book.id)
            }
            
            // 3. macOS 专属的星空点缀弥散光
            #if os(macOS)
            Circle()
                .fill(Color.indigo.opacity(0.08))
                .blur(radius: 120)
                .frame(width: 800, height: 800)
                .offset(x: -200, y: -300)
            #endif
        }
        .ignoresSafeArea()
    }
}
