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
        let schema = Schema([Book.self, ReadingSession.self, BookAnnotation.self, UserConfig.self, Snippet.self])
            
        // ========================================================
        // 🛑 核心修复：Xcode 预览环境拦截器
        // 绝对禁止在写 UI 代码时去碰触真实沙盒与 App Group！防止疯狂弹窗！
        // ========================================================
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            print("👁️ [SharedDatabase] 检测到 Xcode 预览环境，强制拉闸，切断磁盘访问！")
            self.sharedDefaults = UserDefaults.standard // 降级到标准，不碰 group
            let previewConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            self.container = try! ModelContainer(for: schema, configurations: [previewConfig])
            return // ⚠️ 直接 return，绝对不执行下面的物理磁盘代码！
        }
            
        // ========================================================
        // 以下是真实的物理数据库加载逻辑（只有在 Run 模拟器或真机时才会执行）
        // ========================================================
            
        // 初始化共享的 UserDefaults
        self.sharedDefaults = UserDefaults(suiteName: "group.com.akram.library") ?? UserDefaults.standard
            
        let fileManager = FileManager.default
        let targetURL: URL
            
        // 动态决定数据库文件名：将测试包与正式包的本地 SQLite 文件彻底隔离
        #if DEBUG
        let databaseFileName = "MyLibrary-Debug.store"
        #else
        let databaseFileName = "MyLibrary.store"
        #endif
            
        // 尝试获取 App Group 共享目录
        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.akram.library") {
            let customDBDirectory = groupURL.appendingPathComponent("MyLibraryData", isDirectory: true)
            if !fileManager.fileExists(atPath: customDBDirectory.path) {
                try? fileManager.createDirectory(at: customDBDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            targetURL = customDBDirectory.appendingPathComponent(databaseFileName)
        } else {
            print("⚠️ 无法获取 App Group 路径。将降级使用本地沙盒目录。")
            let docURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            targetURL = docURL.appendingPathComponent(databaseFileName)
        }
                        
        // ✨ 核心修复 1：动态判断当前是否在小组件扩展环境中 (.appex)
        let isExtension = Bundle.main.bundlePath.hasSuffix(".appex")
                        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: targetURL,
            allowsSave: true,
            // ✨ 主 App 使用 automatic 保持云端同步，小组件强制使用 none 只读本地文件！
            cloudKitDatabase: isExtension ? .none : .automatic
        )
                        
        do {
            self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("📁 数据库已成功挂载: \(targetURL.path)")
        } catch {
            print("🚨 带有 CloudKit 的数据库初始化失败: \(error)")
                            
            // ✨ 核心修复 2：增加降级防线。如果 automatic 失败，先尝试抛弃 CloudKit 挂载物理磁盘，不要直接放弃！
            do {
                let localConfig = ModelConfiguration(schema: schema, url: targetURL, allowsSave: true, cloudKitDatabase: .none)
                self.container = try ModelContainer(for: schema, configurations: [localConfig])
                print("📁 已降级为纯本地磁盘模式挂载: \(targetURL.path)")
            } catch {
                print("🚨 物理磁盘挂载彻底失败: \(error)")
                // 终极防线：内存数据库兜底
                let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                self.container = try! ModelContainer(for: schema, configurations: [fallbackConfig])
                print("⚠️ 已启用纯内存模式兜底。")
            }
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
            for i in 1 ..< allConfigs.count {
                context.delete(allConfigs[i])
            }
            try context.save()
            print("🧹 [系统自愈] 成功清理了 \(allConfigs.count - 1) 条由于 iCloud 冲突产生的冗余配置。")
        }
    } catch {
        print("❌ 配置自愈检查失败: \(error)")
    }
}
