#if os(macOS)
import SwiftUI

struct SettingsView: View {
    @State private var systemMessage: AttributedString? = nil
    @AppStorage("appTheme", store: SharedDatabase.shared.sharedDefaults)
    private var appTheme: Int = 0
    
    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                GeneralSettingsView(systemMessage: $systemMessage)
                    .tabItem { Label("常规", systemImage: "gearshape") }
                
                DataPanelSettingsView(systemMessage: $systemMessage)
                    .tabItem { Label("数据面板", systemImage: "externaldrive") }
                
                // 在 SettingsView 的 TabView 中追加：

                AchievementWallView()
                    .tabItem { Label("成就", systemImage: "rosette") }
            }
            .frame(width: 800, height: 760)
            
            if let msg = systemMessage {
                Text(msg)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary) // 🍏 自适应文本色
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.8)) // 🍏 窗口底色
                    .background(.regularMaterial) // 🍏 系统原生磨砂玻璃
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.15), radius: 10, y: 5)
                    .padding(.top, 24)
                    .transition(.move(edge: .top).combined(with: .scale(scale: 0.9)).combined(with: .opacity))
                    .zIndex(100)
            }
        }
    }
}
#endif
