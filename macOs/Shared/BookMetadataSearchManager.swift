#if os(macOS)
import AppKit
import Foundation
import WebKit

// MARK: - 📦 1. 统一数据模型与协议定义

struct BookSearchResult: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let author: String
    let coverURL: String?
    let description: String?
}

protocol BookMetadataProvider {
    func searchBooks(query: String) async throws -> [BookSearchResult]
}

// MARK: - 🌐 2. 豆瓣隐身浏览器引擎 (第二防线：降维打击)

/// 利用无头 WKWebView 模拟真实用户访问豆瓣，免疫一切常规反爬虫机制。
@MainActor
class DoubanWebViewProvider: NSObject, BookMetadataProvider {
    
    private var webView: WKWebView
    
    override init() {
        let config = WKWebViewConfiguration()
        // 允许媒体播放、阻止弹窗，保持后台绝对安静
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        // ✨ 核心修复：绝对不能用 .zero！赋予它一个真实的桌面级分辨率，突破豆瓣前端的懒加载限制！
        let mockScreenFrame = CGRect(x: 0, y: 0, width: 1280, height: 1080)
        self.webView = WKWebView(frame: mockScreenFrame, configuration: config)
        
        self.webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        super.init()
    }
    
    func searchBooks(query: String) async throws -> [BookSearchResult] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://search.douban.com/book/subject_search?search_text=\(encodedQuery)") else {
            throw NSError(domain: "Search", code: -1, userInfo: [NSLocalizedDescriptionKey: "构建搜索URL失败"])
        }
        
        // 隐身浏览器开始加载豆瓣页面
        let request = URLRequest(url: url)
        webView.load(request)
        
        // 💡 核心轮询机制：豆瓣是 SPA(单页应用)，我们需要等待它的 JS 渲染出 DOM
        // 最多等待 12 秒，每 0.5 秒嗅探一次
        for _ in 0..<24 {
            try await Task.sleep(nanoseconds: 500_000_000) // 等待 0.5 秒
            
            // 注入智能嗅探 JS，同时兼容“搜索列表页”和“ISBN直接跳转详情页”
            let js = """
            (function() {
                // 1. 尝试判定是否直接跳转到了图书详情页 (通常是搜索精确 ISBN 时的豆瓣机制)
                var h1 = document.querySelector('h1 span');
                var detailImg = document.querySelector('#mainpic img');
                if (h1 && detailImg) {
                    var title = h1.innerText;
                    var cover = detailImg.src;
                    var info = document.querySelector('#info') ? document.querySelector('#info').innerText.replace(/\\n/g, ' ') : '';
                    return JSON.stringify([{title: title, cover: cover, meta: info}]);
                }
                
                // 2. 如果在搜索列表页，查找动态渲染的卡片节点
                var items = document.querySelectorAll('.item-root');
                if (items.length === 0) return 'EMPTY';
                
                var result = [];
                // 提取前 5 条结果
                for(var i=0; i<Math.min(items.length, 5); i++) {
                    var item = items[i];
                    var title = item.querySelector('.title-text') ? item.querySelector('.title-text').innerText : '';
                    var img = item.querySelector('img');
                    var cover = img ? img.src : '';
                    var meta = item.querySelector('.meta') ? item.querySelector('.meta').innerText : '';
                    result.push({title: title, cover: cover, meta: meta});
                }
                return JSON.stringify(result);
            })();
            """
            
            if let res = try? await webView.evaluateJavaScript(js) as? String, res != "EMPTY" {
                if let data = res.data(using: .utf8),
                   let parsedArray = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                    
                    var searchResults: [BookSearchResult] = []
                    
                    for dict in parsedArray {
                        let rawTitle = dict["title"] ?? "未知书名"
                        let rawCover = dict["cover"] ?? ""
                        let rawMeta = dict["meta"] ?? ""
                        
                        // 豆瓣的 Meta 通常是 "作者 / 译者 / 出版社 / 出版年"
                        let metaParts = rawMeta.components(separatedBy: "/")
                        var author = "未知作者"
                        if let firstPart = metaParts.first?.trimmingCharacters(in: .whitespacesAndNewlines), !firstPart.isEmpty {
                            // 简单的清洗：如果在详情页抓到一大坨文本，我们截取作者部分
                            if firstPart.contains("作者:") {
                                author = firstPart.components(separatedBy: "作者:").last?.trimmingCharacters(in: .whitespaces) ?? "未知"
                            } else {
                                author = firstPart
                            }
                        }
                        
                        // 只要有书名就收录
                        if !rawTitle.isEmpty {
                            searchResults.append(BookSearchResult(
                                title: rawTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                                author: author,
                                coverURL: rawCover,
                                description: rawMeta.trimmingCharacters(in: .whitespacesAndNewlines)
                            ))
                        }
                    }
                    
                    if !searchResults.isEmpty {
                        return searchResults
                    }
                }
            }
        }
        
        throw NSError(domain: "Timeout", code: -1, userInfo: [NSLocalizedDescriptionKey: "云端检索超时。豆瓣的防线今天比较顽固。"])
    }
}


// MARK: - 🗜️ 3. 高性能网络图片下载与压缩引擎

enum ImageProcessor {
    static func downloadAndCompress(urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        
        // 伪装头部，突破豆瓣图片的防盗链 (403 Forbidden)
        request.setValue("https://book.douban.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15.0
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return compressImage(data: data)
        } catch {
            return nil
        }
    }
    
    private static func compressImage(data: Data) -> Data? {
        guard let image = NSImage(data: data) else { return nil }
        let maxDimension: CGFloat = 600.0
        let originalSize = image.size
        guard originalSize.width > maxDimension || originalSize.height > maxDimension else {
            return image.jpegData(compressionQuality: 0.8)
        }
        
        let ratio = maxDimension / max(originalSize.width, originalSize.height)
        let newSize = NSSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
        let targetImage = NSImage(size: newSize)
        
        targetImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize), from: NSRect(origin: .zero, size: originalSize), operation: .copy, fraction: 1.0)
        targetImage.unlockFocus()
        
        return targetImage.jpegData(compressionQuality: 0.8)
    }
}

private extension NSImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiffRepresentation = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}

// MARK: - ⚙️ 4. 门面封装 (Facade)

class BookMetadataSearchManager {
    // 强制系统在主线程初始化这个带 WebView 的单例
    @MainActor static let shared = BookMetadataSearchManager()
    
    private let provider: BookMetadataProvider
    
    @MainActor
    private init() {
        // ✨ 将数据源切换为我们无敌的隐身浏览器 (豆瓣)
        self.provider = DoubanWebViewProvider()
    }
    
    @MainActor
    func search(query: String) async throws -> [BookSearchResult] {
        return try await provider.searchBooks(query: query)
    }
    
    func fetchCoverData(from urlString: String?) async -> Data? {
        guard let urlString = urlString, !urlString.isEmpty else { return nil }
        return await ImageProcessor.downloadAndCompress(urlString: urlString)
    }
}
#endif
