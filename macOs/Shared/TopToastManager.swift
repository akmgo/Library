#if os(macOS)
import AppKit
import SwiftUI

/// 🌟 全局桌面级顶部悬浮通知管理器
class TopToastManager {
    static let shared = TopToastManager()
    private var currentPanel: NSPanel?
    
    private init() {}
    
    /// 弹出通知
    /// - Parameters:
    ///   - message: 通知文案
    ///   - icon: SF Symbols 图标名
    func show(message: String, icon: String = "exclamationmark.triangle.fill") {
        DispatchQueue.main.async {
            // 1. 如果有旧通知，瞬间移除
            self.currentPanel?.close()
            
            // 2. 🎨 构建极其优雅的 SwiftUI 视图
            let toastView = HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.orange)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(message)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary.opacity(0.85))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .appCapsuleStyle(tint: AppColors.readingAmber, fillOpacity: 0.15, strokeOpacity: 0.10)
            .padding(.top, 40) // 距离屏幕顶部的安全距离
            
            // 3. 封装进原生的 HostingView
            let hostingView = NSHostingView(rootView: toastView)
            
            // 4. 🪟 创建无边框、无焦点、悬浮面板 (NSPanel)
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            // .floating 级别确保它永远盖在所有普通窗口之上
            panel.level = .floating
            panel.contentView = hostingView
            
            // 5. 定位到主屏幕中上部
            if let screen = NSScreen.main {
                let screenRect = screen.visibleFrame
                // 根据实际内容自适应大小
                let fittingSize = hostingView.fittingSize
                let x = screenRect.midX - (fittingSize.width / 2)
                let y = screenRect.maxY - fittingSize.height
                panel.setFrame(NSRect(x: x, y: y, width: fittingSize.width, height: fittingSize.height), display: true)
            }
            
            // 6. 🎬 极其丝滑的入场动画 (向下微移 + 渐显)
            panel.alphaValue = 0
            panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: panel.frame.minY + 20))
            panel.orderFront(nil)
            
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.4
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
                panel.animator().setFrameOrigin(NSPoint(x: panel.frame.minX, y: panel.frame.minY - 20))
            }
            
            self.currentPanel = panel
            
            // 7. ⏳ 3秒后优雅退场
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak panel] in
                guard let panel = panel, panel == self.currentPanel else { return }
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.3
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    panel.animator().alphaValue = 0
                    panel.animator().setFrameOrigin(NSPoint(x: panel.frame.minX, y: panel.frame.minY + 10))
                }, completionHandler: {
                    panel.close()
                })
            }
        }
    }
}
#endif
