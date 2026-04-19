import Foundation
import SwiftData

@MainActor
public class SharedDatabase {
    public static let shared = SharedDatabase()
    
    public let container: ModelContainer
    // ✨ 统一管理 App Group 的 ID，杜绝到处硬编码
    public let groupID = "group.com.akram.library"
    // ✨ 统一对外提供共享的 UserDefaults
    public let sharedDefaults: UserDefaults

    private init() {
        // 初始化共享的 UserDefaults
        self.sharedDefaults = UserDefaults(suiteName: "group.com.akram.library") ?? UserDefaults.standard
        
        let schema = Schema([Book.self, ReadingRecord.self, Note.self, Excerpt.self, UserConfig.self])
        let fileManager = FileManager.default
        let targetURL: URL
        
        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.akram.library") {
            let customDBDirectory = groupURL.appendingPathComponent("MyLibraryData", isDirectory: true)
            if !fileManager.fileExists(atPath: customDBDirectory.path) {
                try? fileManager.createDirectory(at: customDBDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            targetURL = customDBDirectory.appendingPathComponent("MyLibrary.store")
        } else {
            print("⚠️ 无法获取 App Group 路径。将降级使用本地沙盒目录。")
            let docURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            targetURL = docURL.appendingPathComponent("MyLibrary.store")
        }
        
        // 保持读写和云端同步权限，防止小组件由于 Schema 权限不匹配被系统击毙
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: targetURL,
            allowsSave: true,
            cloudKitDatabase: .automatic
        )
        
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("📁 数据库已成功挂载: \(targetURL.path)")
        } catch {
            print("🚨 真实数据库初始化失败: \(error)")
            // 终极防线：内存数据库兜底，防止进程彻底崩溃
            let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: [fallbackConfig])
        }
        
    }
}

@MainActor
func pruneDuplicateConfigs(context: ModelContext) {
    do {
        // 1. 查询所有配置，按时间降序排列
        let descriptor = FetchDescriptor<UserConfig>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let allConfigs = try context.fetch(descriptor)
        
        // 2. 如果没有任何配置，初始化一个兜底的
        if allConfigs.isEmpty {
            context.insert(UserConfig())
            try context.save()
            return
        }
        
        // 3. ✨ 核心杀毒逻辑：只要超过 1 条，就把后面的全部物理删除
        if allConfigs.count > 1 {
            for i in 1..<allConfigs.count {
                context.delete(allConfigs[i])
            }
            try context.save()
            print("🧹 [系统自愈] 成功清理了 \(allConfigs.count - 1) 条由于 iCloud 冲突产生的冗余配置。")
        }
    } catch {
        print("❌ 配置自愈检查失败: \(error)")
    }
}


