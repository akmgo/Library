import Foundation
import SwiftData

/// 掌控全应用持久化存储的全局单例管理器。
///
/// **核心职责：**
/// 1. **容器组装**：集中定义了系统所需的全局 `Schema`，并生成支持 CloudKit 的 `ModelContainer`。
/// 2. **数据打通**：通过统一定义 `App Group ID`，确保 iOS 主 App 与各种小组件（Widgets、Live Activity）能够访问同一个底层 SQLite 文件。
/// 3. **故障降级**：如果磁盘访问权限被阻断，具备回落至内存数据库的安全自愈机制。
@MainActor
public class SharedDatabase {
    /// 数据库全局单例。
    public static let shared = SharedDatabase()
    
    /// 核心数据库上下文容器，提供给整个生命周期使用。
    public let container: ModelContainer
    
    /// 统一管理的 App Group 标识符，供小组件和主 App 跨进程共享目录使用。
    public let groupID = "group.com.akram.library"
    
    /// 绑定到共享 App Group 的偏好设置中心，用于多进程间的基础状态同步。
    public let sharedDefaults: UserDefaults

    /// 挂载并初始化全局 SwiftData 引擎。
    private init() {
        // 初始化共享的 UserDefaults
        self.sharedDefaults = UserDefaults(suiteName: "group.com.akram.library") ?? UserDefaults.standard
        
        let schema = Schema([Book.self, ReadingRecord.self, Note.self, Excerpt.self, UserConfig.self])
        let fileManager = FileManager.default
        let targetURL: URL
        
        // 尝试获取 App Group 共享目录，使 Widgets 能读写同一份文件
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

/// 执行 iCloud 数据冲突自愈操作：剔除冗余的重复用户配置。
///
/// 由于 CloudKit 多端同步的网络延迟，`UserConfig` 表可能会出现并行创建导致的多条脏数据。
/// 此逻辑通过检索所有配置并按时间降序排列，保留最新的一条，物理销毁其余过期记录。
///
/// - Parameter context: 用于执行检索与删除操作的数据库事务上下文。
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
        
        // 3. 核心杀毒逻辑：只要超过 1 条，就把后面的全部物理删除
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
