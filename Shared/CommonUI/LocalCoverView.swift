import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - 跨端本地封面渲染组件

/// 高性能的跨端本地封面图片渲染组件。
///
/// 该视图专门用于处理从数据库或本地存储中读取的原始图片数据 (`Data`)。
/// 它内置了**异步加载**、**内存缓存**以及**跨平台 (iOS/macOS) 图像解析**引擎。
///
/// **视觉特性：**
/// - 加载中：显示系统标准的二级占位色 (`Color.secondary`)。
/// - 加载失败：显示带有书籍名称的原生风格骨架屏。
/// - 加载成功：执行丝滑的 `0.4` 秒淡入动画。
///
/// - Parameters:
///   - coverData: 原始图片二进制数据。如果传入 `nil`，将直接展示占位图。
///   - fallbackTitle: 当图片解析失败或为空时，在占位骨架屏上显示的兜底文字。
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
    
    /// 内部使用的兜底占位视图。
    ///
    /// 当图片完全无法加载时，该视图会使用 iOS/macOS 的原生次级背景色，
    /// 并居中绘制传入的 `fallbackTitle`（支持动态字体缩放）。
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
