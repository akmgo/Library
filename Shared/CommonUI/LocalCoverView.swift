import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct LocalCoverView: View {
    let coverData: Data?
    let fallbackTitle: String
    
    @State private var loadedImage: PlatformImage? = nil
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let image = loadedImage {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                #else
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                #endif
            } else if isLoading && coverData != nil {
                // 🍏 原生骨架屏：使用系统自带的 secondary 语义色
                Color.secondary.opacity(0.2)
            } else {
                // 🍏 原生文字占位：使用系统次级背景和原生 Headline 字体
                fallbackView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: coverData) {
            isLoading = true
            
            guard let data = coverData else {
                isLoading = false
                return
            }
            
            // 直接在后台任务中处理，不需要 Task.detached
            let cacheKey = String(data.hashValue)
            
            // 极速读取缓存
            if let cachedImage = ImageCacheManager.shared.getImage(forKey: cacheKey) {
                self.loadedImage = cachedImage
                self.isLoading = false
                return
            }
            
            // 处理/压缩新图片
            #if os(iOS)
            let targetSize = CGSize(width: 300, height: 450)
            let newImage = ImageCacheManager.shared.downsample(data: data, to: targetSize)
            #else
            let newImage = NSImage(data: data)
            #endif
            
            // 存入缓存
            if let validImage = newImage {
                // ✨ 修复：因为 setImage 不是 async 函数，所以这里去掉 await
                ImageCacheManager.shared.setImage(validImage, forKey: cacheKey)
            }
            
            // 回到主线程更新 UI 绑定的 State
            await MainActor.run {
                self.loadedImage = newImage
                self.isLoading = false
            }
        }
    }
    
    // MARK: - 🍏 原生化占位视图
    private var fallbackView: some View {
        ZStack {
            #if os(macOS)
            Color(NSColor.controlBackgroundColor)
            #else
            Color(uiColor: .secondarySystemBackground)
            #endif
            
            Text(fallbackTitle.isEmpty ? "未命名" : fallbackTitle)
                .font(.headline) // 🍏 使用原生动态字体，支持无障碍缩放
                .foregroundColor(.secondary) // 🍏 自动适应深浅模式的次级文字颜色
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}
