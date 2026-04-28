#if os(macOS)
import SwiftUI
import SwiftData
import WebKit
internal import Combine
import ImageIO

// MARK: - ✨ 内存缓存容器
class DiscoveryCoverCache {
    static let shared = NSCache<NSString, NSImage>()
}

// MARK: - 🗺️ 发现模块枚举与智能翻页 URL 映射

enum DiscoveryCategory: String, CaseIterable {
    case latest = "新书速递"
    case classic = "传世名著"
    case top250 = "高分必读"
    
    func targetURL(page: Int) -> URL? {
        let baseUrl = "https://book.douban.com"
        switch self {
        case .latest:
            if page > 0 { return nil }
            return URL(string: "\(baseUrl)/latest")
        case .classic:
            let tag = "名著".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
            return URL(string: "\(baseUrl)/tag/\(tag)?start=\(page * 20)&type=S")
        case .top250:
            return URL(string: "\(baseUrl)/top250?start=\(page * 25)")
        }
    }
    
    var themeColor: Color {
        switch self {
        case .latest: return .blue; case .classic: return .purple; case .top250: return .orange
        }
    }
}

// 💾 磁盘持久化中转模型
struct CachedBook: Codable {
    let title: String
    let author: String
    let coverURL: String?
    let description: String?
}

struct DiscoveryDiskCache: Codable {
    let version: Int // ✨ 核心修复：引入缓存版本控制！旧缓存由于缺少此字段，会强制解码失败并失效
    let timestamp: Date
    let visibleBooks: [String: [CachedBook]]
    let bufferPools: [String: [CachedBook]]
}

// MARK: - ⚙️ 发现频道中央调度引擎

@MainActor
class DiscoveryEngine: ObservableObject {
    static let shared = DiscoveryEngine()
    
    @Published var visibleBooks: [DiscoveryCategory: [BookSearchResult]] = [:]
    @Published var isFetching: [DiscoveryCategory: Bool] = [:]
    private var bufferPools: [DiscoveryCategory: [BookSearchResult]] = [:]
    
    private let currentCacheVersion = 1 // 当前缓存版本
    
    private var blacklistedTitles: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "DiscoveryBlacklist") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "DiscoveryBlacklist") }
    }
    
    private var cacheFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("DiscoveryDataCache.json")
    }
    
    private init() {
        for category in DiscoveryCategory.allCases {
            visibleBooks[category] = []
            bufferPools[category] = []
            isFetching[category] = false
        }
    }
    
    // MARK: - 💾 本地持久化逻辑
    
    private func saveToDisk() {
        var visibleDict: [String: [CachedBook]] = [:]
        var bufferDict: [String: [CachedBook]] = [:]
        for cat in DiscoveryCategory.allCases {
            visibleDict[cat.rawValue] = (visibleBooks[cat] ?? []).map { CachedBook(title: $0.title, author: $0.author, coverURL: $0.coverURL, description: $0.description) }
            bufferDict[cat.rawValue] = (bufferPools[cat] ?? []).map { CachedBook(title: $0.title, author: $0.author, coverURL: $0.coverURL, description: $0.description) }
        }
        
        let url = self.cacheFileURL
        // 保存时带上版本号
        let cache = DiscoveryDiskCache(version: currentCacheVersion, timestamp: Date(), visibleBooks: visibleDict, bufferPools: bufferDict)
        if let data = try? JSONEncoder().encode(cache) {
            Task.detached(priority: .background) { try? data.write(to: url) }
        }
    }
    
    private func loadFromDisk() -> Bool {
        guard let data = try? Data(contentsOf: cacheFileURL),
              let cache = try? JSONDecoder().decode(DiscoveryDiskCache.self, from: data) else {
            // 如果解码失败（比如遇到了没有 version 字段的旧缓存），直接返回 false 触发重抓
            return false
        }
        
        // 版本不对或过期，失效
        if cache.version != currentCacheVersion || Date().timeIntervalSince(cache.timestamp) > 86400 { return false }
        
        var isValid = true
        for cat in DiscoveryCategory.allCases {
            let visCached = cache.visibleBooks[cat.rawValue] ?? []
            let bufCached = cache.bufferPools[cat.rawValue] ?? []
            if visCached.count < 10 { isValid = false }
            
            visibleBooks[cat] = visCached.map { BookSearchResult(title: $0.title, author: $0.author, coverURL: $0.coverURL, description: $0.description) }
            bufferPools[cat] = bufCached.map { BookSearchResult(title: $0.title, author: $0.author, coverURL: $0.coverURL, description: $0.description) }
        }
        return isValid
    }
    
    // MARK: - 🚀 主力加载逻辑
    
    func loadAllCategories(context: ModelContext) async {
        if visibleBooks.values.allSatisfy({ $0.isEmpty }) {
            _ = loadFromDisk()
        }
        
        await withTaskGroup(of: Void.self) { group in
            for category in DiscoveryCategory.allCases {
                let currentCount = visibleBooks[category]?.count ?? 0
                if currentCount < 10 {
                    group.addTask { await self.fetchCategory(category, context: context) }
                }
            }
        }
    }
    
    // 排重专用的核心词提取
    private func extractCoreTitle(from title: String) -> String {
        var t = title
        if let idx = t.firstIndex(of: "(") { t = String(t[..<idx]) }
        if let idx = t.firstIndex(of: "（") { t = String(t[..<idx]) }
        if let idx = t.firstIndex(of: ":") { t = String(t[..<idx]) }
        if let idx = t.firstIndex(of: "：") { t = String(t[..<idx]) }
        if let idx = t.firstIndex(of: "-") { t = String(t[..<idx]) }
        return t.trimmingCharacters(in: .whitespaces)
    }
    
    // ✨ 深度展示清洗算法
    private func cleanDisplayTitle(_ title: String) -> String {
        var t = title
        
        // 1. 清理括号包裹的废话：(全集)、(第一部)、[纪念版]等
        let pattern1 = "\\s*[\\(（\\[【](上下|上、下|上中下|全集|全.+?册|上下册|纪念版|修订版|精华版|第.+?[部卷季册章])[\\)）\\]】]"
        t = t.replacingOccurrences(of: pattern1, with: "", options: .regularExpression)
        
        // 2. 清理独立作为后缀的部、卷、季标识：例如 " 第1部"、"·第一卷"、" - 第2季"
        let pattern2 = "(\\s+|\\s*[·\\-:]\\s*)第.+?[部卷季册章]\\s*$"
        t = t.replacingOccurrences(of: pattern2, with: "", options: .regularExpression)
        
        return t.trimmingCharacters(in: .whitespaces)
    }
    
    // 作者清洗
    private func cleanAuthorName(_ rawMeta: String) -> String {
        var author = rawMeta.components(separatedBy: "/").first?.trimmingCharacters(in: .whitespaces) ?? "未知作者"
        let nationPattern = "^[\\[\\(（【].{1,5}[\\]\\)）】]\\s*"
        author = author.replacingOccurrences(of: nationPattern, with: "", options: .regularExpression)
        let englishNamePattern = "\\s*[\\(（][A-Za-z\\s\\.\\-]+[\\)）]"
        author = author.replacingOccurrences(of: englishNamePattern, with: "", options: .regularExpression)
        return author.trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - 🕸️ 抗灾抓取算法
    private func fetchCategory(_ category: DiscoveryCategory, context: ModelContext) async {
        guard isFetching[category] != true else { return }
        isFetching[category] = true
        defer { isFetching[category] = false }
        
        let allLocalBooks = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        let localTitles = Set(allLocalBooks.map { $0.title })
        let currentBlacklist = self.blacklistedTitles
        
        var uniquePool: [BookSearchResult] = []
        uniquePool.append(contentsOf: visibleBooks[category] ?? [])
        uniquePool.append(contentsOf: bufferPools[category] ?? [])
        
        var page = 0
        let maxPages = 3
        
        while uniquePool.count < 20 && page < maxPages {
            guard let url = category.targetURL(page: page) else { break }
            
            do {
                let rawBooks = try await scrapeRealChartPage(url: url)
                if rawBooks.isEmpty { break }
                
                for book in rawBooks {
                    if localTitles.contains(book.title) || currentBlacklist.contains(book.title) { continue }
                    if book.coverURL == nil || book.coverURL!.isEmpty { continue }
                    
                    let coreTitle = extractCoreTitle(from: book.title)
                    let isDuplicate = uniquePool.contains { extractCoreTitle(from: $0.title) == coreTitle }
                    if !isDuplicate { uniquePool.append(book) }
                }
                
                page += 1
                if uniquePool.count < 20 && page < maxPages {
                    try await Task.sleep(nanoseconds: 1_500_000_000)
                }
                
            } catch {
                print("栏目 \(category.rawValue) 第 \(page) 页抓取失败，保留已有数据: \(error)")
                break
            }
        }
        
        let initialDisplay = Array(uniquePool.prefix(10))
        if uniquePool.count >= 10 { uniquePool.removeFirst(10) } else { uniquePool.removeAll() }
        
        withAnimation(.appFluidSpring) {
            self.visibleBooks[category] = initialDisplay
            self.bufferPools[category] = uniquePool
        }
        self.saveToDisk()
    }
    
    func consumeAndReplenish(bookID: UUID, in category: DiscoveryCategory) {
        guard var currentVisible = visibleBooks[category], let indexToRemove = currentVisible.firstIndex(where: { $0.id == bookID }) else { return }
        currentVisible.remove(at: indexToRemove)
        
        if var pool = bufferPools[category], !pool.isEmpty {
            let nextBook = pool.removeFirst()
            currentVisible.append(nextBook)
            bufferPools[category] = pool
        }
        
        withAnimation(.appFluidSpring) { self.visibleBooks[category] = currentVisible }
        saveToDisk()
    }
    
    func dismissBook(_ book: BookSearchResult, in category: DiscoveryCategory) {
        var currentBlacklist = blacklistedTitles
        currentBlacklist.insert(book.title)
        blacklistedTitles = currentBlacklist
        consumeAndReplenish(bookID: book.id, in: category)
    }
    
    private func scrapeRealChartPage(url: URL) async throws -> [BookSearchResult] {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        let temporaryWebView = WKWebView(frame: .zero, configuration: config)
        temporaryWebView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        let request = URLRequest(url: url); temporaryWebView.load(request)
        
        for _ in 0..<20 {
            try await Task.sleep(nanoseconds: 600_000_000)
            let js = "(function(){var results=[];var items=document.querySelectorAll('li.subject-item, tr.item, .detail-frame, li.media, .item-root');if(items.length===0)return 'EMPTY';for(var i=0;i<items.length;i++){var node=items[i];var titleNode=node.querySelector('h2 a, .pl2 a, h4 a, h3 a, .title a, a.title');if(!titleNode)continue;var title=titleNode.innerText.replace(/\\n/g,'').trim();var imgNode=node.querySelector('img');var cover=imgNode?imgNode.src:'';var pubNode=node.querySelector('.pub, p.pl, .color-gray, .meta');var meta=pubNode?pubNode.innerText.replace(/\\n/g,'').trim():'';var ratingNode=node.querySelector('.rating_nums, .rating_num');var rating=ratingNode?ratingNode.innerText.trim():'';var inqNode=node.querySelector('.inq, .info p, .detail, .abstract');var desc=inqNode?inqNode.innerText.replace(/\\n/g,'').trim():'';results.push({title:title,cover:cover,meta:meta,rating:rating,desc:desc});}return JSON.stringify(results);})();"
            if let res = try? await temporaryWebView.evaluateJavaScript(js) as? String, res != "EMPTY", res != "[]" {
                if let data = res.data(using: .utf8), let parsedArray = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                    let finalBooks = parsedArray.compactMap { dict -> BookSearchResult? in
                        guard let rawTitle = dict["title"], !rawTitle.isEmpty, let cover = dict["cover"] else { return nil }
                        
                        let title = self.cleanDisplayTitle(rawTitle)
                        let rawMeta = dict["meta"] ?? ""
                        let author = self.cleanAuthorName(rawMeta)
                        
                        return BookSearchResult(title: title, author: author, coverURL: cover, description: "")
                    }
                    if !finalBooks.isEmpty { return finalBooks }
                }
            }
        }
        throw URLError(.timedOut)
    }
}
#endif
