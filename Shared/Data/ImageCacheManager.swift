import Foundation
import SwiftUI
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

/// 全局统一的高性能图片缓存管理器。
///
/// 使用底层 `NSCache` 实现，同时支持跨平台的本地图片压缩与降采样。
/// 单例模式，全局共享，禁止外部初始化。
final class ImageCacheManager: @unchecked Sendable {
    static let shared = ImageCacheManager()

    private let cache = NSCache<NSString, PlatformImage>()

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    /// 读取图片 (线程安全)
    func getImage(forKey key: String) -> PlatformImage? {
        cache.object(forKey: key as NSString)
    }

    /// 写入图片 (线程安全)
    func setImage(_ image: PlatformImage, forKey key: String) {
        #if os(iOS)
        let cost = Int(image.size.width * image.size.height * image.scale)
        #else
        let cost = Int(image.size.width * image.size.height)
        #endif
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    /// 清除所有缓存 (线程安全)
    func clearCache() {
        cache.removeAllObjects()
    }

    /// 移除指定 key 的缓存
    func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    /// 跨平台缩略图降采样。
    ///
    /// 利用 `ImageIO` 在解码前进行缩略图计算，极大降低内存峰值。
    ///
    /// - Parameters:
    ///   - data: 原始图片二进制数据。
    ///   - pointSize: 目标逻辑尺寸。
    ///   - scale: 缩放因子，默认 3.0。
    /// - Returns: 降采样后的 `CGImage`，失败返回 `nil`。
    public func downsample(data: Data, to pointSize: CGSize, scale: CGFloat = 3.0) -> CGImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else { return nil }

        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary

        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions)
    }
}
