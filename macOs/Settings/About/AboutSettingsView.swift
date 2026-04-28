#if os(macOS)
import SwiftUI
import AppKit

struct AboutSettingsView: View {
    
    // ✨ 动态获取 Xcode 中配置的真实版本号和 Build 号
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 巨大的 App Icon 占位
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [.indigo, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                    .shadow(color: .indigo.opacity(0.3), radius: 20, y: 10)
                
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("MyLibrary")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
                
                // ✨ 补充一句话的应用标语（Slogan），提升产品格调
                Text("构建属于你自己的纯粹阅读资产库")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.top, 4)
            }
            
            Spacer()
            
            // ================= 交互链接区 =================
            VStack(spacing: 16) {
                // 替换掉 GitHub，放入你的个人主页
                Button(action: {
                    if let url = URL(string: "https://akram.top") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label("访问开发者主页", systemImage: "globe")
                        .frame(width: 160, alignment: .leading)
                }
                .buttonStyle(.link)
                
                // 原生邮件唤起逻辑：自动填入你的邮箱和默认邮件主题
                Button(action: {
                    let email = "akmgo2024@outlook.com"
                    let subject = "MyLibrary 反馈与建议".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "mailto:\(email)?subject=\(subject)") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label("通过邮件联系开发者", systemImage: "envelope")
                        .frame(width: 160, alignment: .leading)
                }
                .buttonStyle(.link)
            }
            
            Spacer()
            
            // ================= 底部版权信息 =================
            VStack(spacing: 4) {
                Text("Designed and Crafted by Akram")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
                
                // 动态获取当前年份，无需每年手动修改
                Text("Copyright © \(String(Calendar.current.component(.year, from: Date()))) Akram. All rights reserved.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.03))
    }
}
#endif
