#if os(macOS)
import Foundation
import SQLite3

// MARK: - Apple Books 核心数据传输对象 (DTO)

/// 代表从 Apple Books 提取的单条高亮/批注记录。
///
/// 该结构体作为一个纯粹的数据载体，用于在底层 C API 和上层 SwiftData 实体之间传递数据。
public struct AppleAnnotation {
    /// 批注的唯一标识符。
    public var uuid: String
    /// 用户划线或批注的纯文本内容。
    public var text: String
    /// 批注的创建时间。
    public var creationDate: Date
}

/// 代表从 Apple Books 提取的单本书籍元数据。
///
/// 包含了用于构建本地书籍副本所需的所有核心信息，包括系统内部的资源 ID、
/// 书名、作者、阅读进度以及关键的时间戳。
public struct AppleBookInfo {
    /// 苹果系统内部的书籍资源唯一标识符 (Asset ID)。
    public var assetId: String
    public var title: String
    public var author: String
    /// 书籍的绝对阅读百分比进度 (0~100)。
    public var progress: Int
    public var creationDate: Date?
    public var lastOpenDate: Date?
}

// MARK: - Apple Books 数据库直读引擎

/// 专门用于读取和解析 macOS 原生 Apple Books (iBooks) 底层 SQLite 数据库的核心工具类。
///
/// **核心职责与突破：**
/// 1. **沙盒击穿**：通过 C 语言级别的 API 绕过标准沙盒限制，获取真实的 Mac 用户主目录。
/// 2. **无感克隆**：由于原库被系统级进程（`bookd`）长期独占锁死，此类在读取前会自动将原库（含 WAL 和 SHM 缓存文件）无感克隆至临时目录，实现安全的只读操作。
/// 3. **SQL 解析**：使用底层 `sqlite3` API 执行原生查询，提取书籍列表、进度和批注。
public class AppleBooksDBUtils {
    
    // MARK: - 缓存与沙盒穿透状态
    
    /// 记录指定目录数据库最后一次克隆的绝对时间戳，用于 10 秒内的缓存防抖。
    private static var cloneTimestamps: [String: Date] = [:]
    /// 记录指定目录数据库最后一次克隆在沙盒内的安全可读绝对路径。
    private static var clonePaths: [String: String] = [:]
    
    /// 通过底层 C API 获取系统当前用户的真实主目录路径（如 `/Users/akram`）。
    ///
    /// - 注意: 常规的 `NSHomeDirectory()` 会被系统重定向到当前 App 的沙盒内部，
    /// 只有通过 `getpwuid` 才能获取真正的磁盘物理根目录，从而跨区访问 Apple Books 库。
    private static var realHomeDirectory: String {
        guard let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir else {
            return NSHomeDirectory()
        }
        return String(cString: dir)
    }
    
    // MARK: - 内部控制逻辑
    
    /// 解析目标数据库路径，并执行沙盒越权与安全克隆。
    ///
    /// 1. 将路径中的 `~` 替换为绝对物理主目录。
    /// 2. 检查 10 秒防抖缓存。
    /// 3. 扫描并连同 `-wal` (预写日志) 和 `-shm` 内存映射文件一起拷贝，以防止数据库读取出现“幽灵丢失”。
    ///
    /// - Parameters:
    ///   - directory: 包含 `.sqlite` 文件的目标文件夹相对/绝对路径。
    ///
    /// - Returns: 返回在临时安全沙盒中建立的克隆数据库物理路径。如果克隆失败则返回 `nil`。
    private static func findDatabasePath(directory: String) -> String? {
        // ✨ 核心修复 3：用真实的绝对路径替换 "~"，打破路径套娃！
        let expandedDir = directory.replacingOccurrences(of: "~", with: realHomeDirectory)
        let fm = FileManager.default
        
        // 1. 缓存机制：如果 10 秒内拷贝过该库，直接返回缓存路径
        if let time = cloneTimestamps[expandedDir], let path = clonePaths[expandedDir], Date().timeIntervalSince(time) < 10 {
            return path
        }
        
        // 2. 执行影分身拷贝
        do {
            let files = try fm.contentsOfDirectory(atPath: expandedDir)
            guard let sqliteFile = files.first(where: { $0.hasSuffix(".sqlite") && !$0.contains("-wal") && !$0.contains("-shm") }) else {
                return nil
            }
            
            let originalPath = "\(expandedDir)/\(sqliteFile)"
            
            // 在安全的临时目录建立对应的专属克隆文件夹
            let safeDirName = expandedDir.contains("AEAnnotation") ? "AEAnnotationClone" : "BKLibraryClone"
            let tempDir = fm.temporaryDirectory.appendingPathComponent(safeDirName, isDirectory: true)
            
            // 每次拷贝前清空旧文件夹
            if fm.fileExists(atPath: tempDir.path) {
                try fm.removeItem(at: tempDir)
            }
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            
            let clonePath = tempDir.appendingPathComponent(sqliteFile).path
            
            // ⚠️ 致命细节：必须连同 -wal 和 -shm 一起克隆，SQLite 才能正常建立连接！
            for ext in ["", "-wal", "-shm"] {
                let src = originalPath + ext
                let dst = clonePath + ext
                if fm.fileExists(atPath: src) {
                    try fm.copyItem(atPath: src, toPath: dst)
                }
            }
            
            // 记录缓存并返回
            cloneTimestamps[expandedDir] = Date()
            clonePaths[expandedDir] = clonePath
            return clonePath
            
        } catch {
            print("❌ Apple Books 数据库影分身创建失败: \(error)")
            return nil
        }
    }
    
    // MARK: - 公开查询 API
    
    /// 根据书名，精确获取该书籍在苹果系统中的最新阅读进度。
    ///
    /// - Parameters:
    ///   - title: 书籍的完整标题。
    ///
    /// - Returns: 返回 `0~100` 的整数进度。如果未找到或查询失败返回 `nil`。
    public static func fetchBookProgress(byTitle title: String) -> Int? {
        guard let dbPath = findDatabasePath(directory: "~/Library/Containers/com.apple.iBooksX/Data/Documents/BKLibrary") else { return nil }
        
        var db: OpaquePointer?
        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK { return nil }
        defer { sqlite3_close(db) }
        
        let query = "SELECT ZREADINGPROGRESS FROM ZBKLIBRARYASSET WHERE ZTITLE = ? COLLATE NOCASE LIMIT 1"
        var statement: OpaquePointer?
        var progressInt: Int? = nil
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (title as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                let progressDouble = sqlite3_column_double(statement, 0)
                // ✨ 加上 round() 四舍五入，完美解决浮点数截断问题
                progressInt = Int(round(progressDouble * 100))
            }
        }
        sqlite3_finalize(statement)
        return progressInt
    }
    
    /// 根据书名，提取其在 Apple Books 系统中的唯一资源标识符 (Asset ID)。
    ///
    /// - Parameters:
    ///   - title: 书籍的完整标题。
    ///
    /// - Returns: 返回系统内部的唯一标识符字符串，用于后续跨表查询摘录等信息。
    public static func fetchAssetId(byTitle title: String) -> String? {
        guard let dbPath = findDatabasePath(directory: "~/Library/Containers/com.apple.iBooksX/Data/Documents/BKLibrary") else { return nil }
            
        var db: OpaquePointer?
        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK { return nil }
        defer { sqlite3_close(db) }
            
        let query = "SELECT ZASSETID FROM ZBKLIBRARYASSET WHERE ZTITLE = ? COLLATE NOCASE LIMIT 1"
        var statement: OpaquePointer?
        var assetId: String? = nil
            
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (title as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                if let idPtr = sqlite3_column_text(statement, 0) {
                    assetId = String(cString: idPtr)
                }
            }
        }
        sqlite3_finalize(statement)
        return assetId
    }
        
    /// 通过 Asset ID 获取该书的所有有效划线与批注。
    ///
    /// - Parameters:
    ///   - assetId: 由 `fetchAssetId(byTitle:)` 返回的系统资源 ID。
    ///
    /// - Returns: 返回包含该书籍所有高亮划线信息的 `AppleAnnotation` 数组，已自动过滤被删除的幽灵记录。
    public static func fetchAnnotations(forAssetId assetId: String) -> [AppleAnnotation] {
        guard let dbPath = findDatabasePath(directory: "~/Library/Containers/com.apple.iBooksX/Data/Documents/AEAnnotation") else { return [] }
            
        var db: OpaquePointer?
        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK { return [] }
        defer { sqlite3_close(db) }
            
        let query = "SELECT ZANNOTATIONUUID, ZANNOTATIONSELECTEDTEXT, ZANNOTATIONCREATIONDATE FROM ZAEANNOTATION WHERE ZANNOTATIONASSETID = ? AND ZANNOTATIONDELETED = 0 AND ZANNOTATIONSELECTEDTEXT IS NOT NULL"
            
        var statement: OpaquePointer?
        var results: [AppleAnnotation] = []
            
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (assetId as NSString).utf8String, -1, nil)
                
            while sqlite3_step(statement) == SQLITE_ROW {
                let uuid = String(cString: sqlite3_column_text(statement, 0))
                let text = String(cString: sqlite3_column_text(statement, 1))
                let timestamp = sqlite3_column_double(statement, 2)
                let date = Date(timeIntervalSinceReferenceDate: timestamp)
                    
                results.append(AppleAnnotation(uuid: uuid, text: text, creationDate: date))
            }
        }
        sqlite3_finalize(statement)
        return results
    }
    
    /// 暴力读取并解析 Apple Books 书架库的完整元数据表。
    ///
    /// 本方法会扫描 `ZBKLIBRARYASSET` 表，提取书名、作者、时间和进度。
    /// 并且会执行极其严格的数据清洗过滤逻辑：
    /// - 过滤被隐藏 (`ZISHIDDEN`) 或被逻辑删除 (`ZISDELETED`) 的脏数据。
    /// - 过滤状态无效或本地不存在的文件 (`ZSTATE`, `ZFILESIZE`)。
    /// - 过滤并非实体图书的有声书 (`ZISSTOREAUDIOBOOK`)。
    ///
    /// - Returns: 返回经过清洗和安全解析的完整 `AppleBookInfo` 清单数组。
    public static func fetchAllBooks() -> [AppleBookInfo] {
        guard let dbPath = findDatabasePath(directory: "~/Library/Containers/com.apple.iBooksX/Data/Documents/BKLibrary") else { return [] }
            
        var db: OpaquePointer?
        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK { return [] }
        defer { sqlite3_close(db) }
            
        let query = "SELECT * FROM ZBKLIBRARYASSET WHERE ZTITLE IS NOT NULL AND ZASSETID IS NOT NULL"
        var statement: OpaquePointer?
        var results: [AppleBookInfo] = []
            
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            var colMap: [String: Int32] = [:]
            let count = sqlite3_column_count(statement)
            for i in 0 ..< count {
                if let namePtr = sqlite3_column_name(statement, i) {
                    colMap[String(cString: namePtr).uppercased()] = i
                }
            }
                
            while sqlite3_step(statement) == SQLITE_ROW {
                // 幽灵数据过滤
                var isHidden = false; var isDeleted = false
                if let idx = colMap["ZISHIDDEN"] { isHidden = sqlite3_column_int(statement, idx) != 0 }
                if let idx = colMap["ZISDELETED"] ?? colMap["ZDELETEDFLAG"] { isDeleted = sqlite3_column_int(statement, idx) != 0 }
                if isHidden || isDeleted { continue }
                    
                if let idx = colMap["ZSTATE"], sqlite3_column_int(statement, idx) == 0 { continue }
                if let idx = colMap["ZDESKTOPSTATE"], sqlite3_column_int(statement, idx) == 0 { continue }
                if let idx = colMap["ZISSTOREAUDIOBOOK"], sqlite3_column_int(statement, idx) != 0 { continue }
                    
                var fileSize = 1; var purchaseDate: Double = 0
                if let idx = colMap["ZFILESIZE"] { fileSize = Int(sqlite3_column_int(statement, idx)) }
                if let idx = colMap["ZPURCHASEDATE"] { purchaseDate = sqlite3_column_double(statement, idx) }
                if fileSize == 0 && purchaseDate == 0 { continue }
                    
                var assetId = ""; var title = "未知"; var author = "未知作者"
                if let idx = colMap["ZASSETID"], let ptr = sqlite3_column_text(statement, idx) { assetId = String(cString: ptr) }
                if let idx = colMap["ZTITLE"], let ptr = sqlite3_column_text(statement, idx) { title = String(cString: ptr) }
                    
                for col in ["ZAUTHOR", "ZBOOKAUTHOR", "ZSORTAUTHOR"] {
                    if let idx = colMap[col], let ptr = sqlite3_column_text(statement, idx) { author = String(cString: ptr); break }
                }
                    
                var progress = 0
                if let idx = colMap["ZREADINGPROGRESS"] { progress = Int(round(sqlite3_column_double(statement, idx) * 100)) }
                
                var creationDate: Date? = nil; var lastOpenDate: Date? = nil
                if let idx = colMap["ZCREATIONDATE"] ?? colMap["ZINSERTIONDATE"] {
                    let ts = sqlite3_column_double(statement, idx); if ts > 0 { creationDate = Date(timeIntervalSinceReferenceDate: ts) }
                }
                if let idx = colMap["ZLASTOPENDATE"] ?? colMap["ZMODIFICATIONDATE"] {
                    let ts = sqlite3_column_double(statement, idx); if ts > 0 { lastOpenDate = Date(timeIntervalSinceReferenceDate: ts) }
                }
                    
                results.append(AppleBookInfo(assetId: assetId, title: title, author: author, progress: progress, creationDate: creationDate, lastOpenDate: lastOpenDate))
            }
        }
        sqlite3_finalize(statement)
        return results
    }
}
#endif
