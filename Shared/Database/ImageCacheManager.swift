import SwiftUI
import ImageIO

#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#else
import UIKit
public typealias PlatformImage = UIImage
#endif

// MARK: - 跨平台图片缓存引擎

/// 全局跨平台图片内存缓存管理器。
///
/// 利用底层的 `NSCache` 提供高性能的图片存取服务。主要用于在瀑布流或列表视图中
/// 极速加载本地解析出的书籍封面，避免重复的磁盘 I/O 或高耗时的图像重采样操作。
///
/// - 注意: 由于 `NSCache` 本身是线程安全的，因此显式标记 `@unchecked Sendable`
/// 以满足 Swift 6 的严格并发检查。
public final class ImageCacheManager: @unchecked Sendable {
    /// 全局唯一的缓存实例。
    public static let shared = ImageCacheManager()
    
    /// 底层缓存容器，键为图片标识字符串，值为对应平台的图像对象。
    private let cache = NSCache<NSString, PlatformImage>()

    /// 初始化缓存策略。
    /// 强制设定硬性上限以防止内存溢出：最多 200 张图片，或最大 100MB 物理内存。
    private init() {
        cache.countLimit = 200 // 最多缓存 200 张封面
        cache.totalCostLimit = 1024 * 1024 * 100 // 物理内存限制 100MB
    }

    /// 从内存中提取已缓存的图像。
    ///
    /// - Parameter key: 图像的唯一标识符（通常使用图像数据的 Hash 值）。
    /// - Returns: 如果命中缓存，返回对应的 `NSImage` 或 `UIImage`，否则返回 `nil`。
    public func getImage(forKey key: String) -> PlatformImage? {
        return cache.object(forKey: key as NSString)
    }

    /// 将解析好的图像写入内存缓存。
    ///
    /// - Parameters:
    ///   - image: 准备缓存的 `NSImage` 或 `UIImage` 对象。
    ///   - key: 图像的唯一标识符。
    public func setImage(_ image: PlatformImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    /// 从内存缓存中强制移除指定的图像。
        ///
        /// - Parameter key: 需要移除的图像的唯一标识符。
        public func removeImage(forKey key: String) {
            cache.removeObject(forKey: key as NSString)
        }
    
    
    #if os(iOS)
    /// 对高分辨率原始图片数据执行极限降采样缩放。
    ///
    /// 此方法利用底层的 `ImageIO` 框架，在解码图像像素前就进行缩略图计算，
    /// 从而极大降低内存峰值 (Memory Footprint)。专为 iOS 移动端内存敏感场景设计。
    ///
    /// - Parameters:
    ///   - data: 原始大图的二进制数据。
    ///   - pointSize: 目标视图在屏幕上的逻辑点尺寸 (Point)。
    ///   - scale: 屏幕的缩放因子 (通常为 @2x 或 @3x，默认为 3.0)。
    ///
    /// - Returns: 降采样成功后返回轻量级的 `UIImage`，若数据损坏则返回 `nil`。
    public func downsample(data: Data, to pointSize: CGSize, scale: CGFloat = 3.0) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else { return nil }
        
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else { return nil }
        return UIImage(cgImage: downsampledImage)
    }
    #endif
}
