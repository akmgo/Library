import SwiftUI
import ImageIO

#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#else
import UIKit
public typealias PlatformImage = UIImage
#endif

// ✨ 声明线程安全，由于 NSCache 本身是线程安全的，因此标注 unchecked
public final class ImageCacheManager: @unchecked Sendable {
    public static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSString, PlatformImage>()

    private init() {
        cache.countLimit = 200 // 最多缓存 200 张封面
        cache.totalCostLimit = 1024 * 1024 * 100 // 物理内存限制 100MB
    }

    public func getImage(forKey key: String) -> PlatformImage? {
        return cache.object(forKey: key as NSString)
    }

    public func setImage(_ image: PlatformImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    #if os(iOS)
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
