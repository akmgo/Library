#if os(macOS)
import Foundation
import SQLite3

public struct AppleAnnotation {
    public var uuid: String
    public var text: String
    public var creationDate: Date
}

public struct AppleBookInfo {
    public var assetId: String
    public var title: String
    public var author: String
    public var progress: Int
    public var creationDate: Date?
    public var lastOpenDate: Date?
}

public class AppleBooksDBUtils {
    
    // ✨ 核心魔法 1：影分身缓存机制
    private static var cloneTimestamps: [String: Date] = [:]
    private static var clonePaths: [String: String] = [:]
    
    // ✨ 核心魔法 2：调用底层 C API 击穿沙盒，获取真实的 Mac 用户主目录！
    private static var realHomeDirectory: String {
        guard let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir else {
            return NSHomeDirectory()
        }
        return String(cString: dir)
    }
    
    /// 获取数据库路径（自动执行沙盒拷贝越权）
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
