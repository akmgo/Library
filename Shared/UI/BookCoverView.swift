import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - 跨端本地封面渲染组件

/// 高性能的跨端本地封面图片渲染组件。
struct BookCoverView: View {
    /// 外部唯一标识符作为缓存 Key，拒绝动态 Hash
    let coverID: String
    let coverData: Data?
    let fallbackTitle: String
    
    @State private var loadedImage: PlatformImage? = nil
    @State private var isLoading = true
    @Environment(\.colorScheme) private var colorScheme

    private var cacheKey: String {
        guard let coverData else { return "cover_img_\(coverID)_empty" }
        return "cover_img_\(coverID)_\(coverData.count)"
    }

    private var coverVersion: String {
        guard let coverData else { return "\(coverID)_empty" }
        return "\(coverID)_\(coverData.count)"
    }
    
    var body: some View {
        ZStack {
            if let image = loadedImage {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    // ✨ 核心 1：必须是 fill，保证无论图片什么比例，都绝对填满父容器
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
                #endif
            } else if isLoading && coverData != nil {
                // 🍏 原生骨架屏
                Color.secondary.opacity(0.2)
            } else {
                // 🍏 原生文字占位
                fallbackView
            }
        }
        // ✨ 核心 2：撑满父容器给予的最大空间
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        // ✨ 核心 3：冷酷无情地切掉所有溢出边界的像素，彻底消灭悬浮时的透明黑框！
        .clipped()
        // 保证整个区域（哪怕是透明部分）都能响应鼠标悬停和点击
        .contentShape(Rectangle())
        .task(id: coverID) {
            await loadCoverImage()
        }
        // ✨ 补上这三行：专门监听封面数据的真实变化
        .onChange(of: coverVersion) { _, _ in
            Task { await loadCoverImage() }
        }
    }
    
    // MARK: - 核心异步加载引擎
    
    @MainActor
    private func loadCoverImage() async {
        // 重置状态
        if !isLoading { isLoading = true }
        
        guard let data = coverData, !coverID.isEmpty else {
            withAnimation {
                loadedImage = nil
                isLoading = false
            }
            return
        }

        // 1. 极速读取内存缓存
        if let cachedImage = ImageCacheManager.shared.getImage(forKey: cacheKey) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.loadedImage = cachedImage
                self.isLoading = false
            }
            return
        }
        
        // 2. 强制剥离主线程处理重度 CPU 运算
        let processedImage = await Task.detached(priority: .userInitiated) { () -> PlatformImage? in
            let targetSize = CGSize(width: 300, height: 450)
            guard let cgImage = await ImageCacheManager.shared.downsample(data: data, to: targetSize) else {
                return nil
            }
            #if os(macOS)
            return NSImage(cgImage: cgImage, size: targetSize)
            #else
            return UIImage(cgImage: cgImage)
            #endif
        }.value
        
        guard let validImage = processedImage else {
            withAnimation {
                loadedImage = nil
                isLoading = false
            }
            return
        }
        
        // 写入缓存 (后台完成，不阻碍 UI)
        ImageCacheManager.shared.setImage(validImage, forKey: cacheKey)
        
        // 3. 回到主线程，触发极简柔和的图片加载淡入动画
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.3)) {
                self.loadedImage = validImage
                self.isLoading = false
            }
        }
    }
    
    // MARK: - 🍏 原生化占位视图
    
    private var fallbackView: some View {
        ZStack {
            AppColors.tertiaryBackground(for: colorScheme)
            
            Text(fallbackTitle.isEmpty ? "未命名" : fallbackTitle)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}
