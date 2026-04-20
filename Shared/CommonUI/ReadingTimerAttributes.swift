#if os(iOS)
import Foundation
import ActivityKit

/// 定义实时活动 (Live Activity) 和灵动岛 (Dynamic Island) 所需的数据结构。
///
/// 这是一个 `ActivityAttributes` 结构体，它定义了两种数据：
/// 1. **静态属性**：在活动启动时确定且不可更改的数据（如书名、作者、封面路径）。
/// 2. **动态状态 (`ContentState`)**：在活动运行期间会不断更新的数据（如倒计时、完成的循环数）。
///
/// - 注意: 为了满足 iOS 18 严格的并发安全要求，该结构体及其内部状态已遵循 `Sendable` 协议。
public struct ReadingTimerAttributes: ActivityAttributes, Sendable {
    
    /// 实时活动的动态内容状态。
    ///
    /// 这些属性会在专注计时期间由主 App 或锁屏交互频繁更新，从而驱动灵动岛和锁屏卡片的 UI 变化。
    public struct ContentState: Codable, Hashable, Sendable {
        
        /// 当前番茄钟循环的目标结束时间（绝对时间戳）。
        ///
        /// 视图层（如 `Text(timerInterval:)`）会使用此绝对时间与当前时间求差，
        /// 从而由底层操作系统接管并实现丝滑不掉帧的倒计时渲染。
        public var cycleEndTime: Date
        
        /// 当前已完整完成的 20 分钟专注循环次数。用于点亮 UI 上的进度圆点。
        public var completedCycles: Int
        
        /// 初始化动态内容状态。
        ///
        /// - Parameters:
        ///   - cycleEndTime: 当前倒计时循环的预期结束时间。
        ///   - completedCycles: 已经完成的循环总数。
        public init(cycleEndTime: Date, completedCycles: Int) {
            self.cycleEndTime = cycleEndTime
            self.completedCycles = completedCycles
        }
    }
    
    // MARK: - 静态属性 (创建后不可变)
    
    /// 正在阅读的书籍标题，用于在锁屏显眼位置展示。
    public var bookTitle: String
    
    /// 正在阅读的书籍作者，用于次级信息展示。
    public var author: String
    
    /// 本地沙盒中当前书籍封面的临时图片路径。
    ///
    /// 实时活动由于内存限制，无法直接传递 `Data`。主程序会在启动活动前，
    /// 将封面保存为共享 AppGroup 目录下的文件，并将绝对路径传递给此属性供读取。
    public var coverFilePath: String?
    
    /// 启动计时时的书籍阅读百分比进度 (0~100)。
    public var bookProgress: Int
    
    /// 初始化实时活动的静态属性。
    ///
    /// - Parameters:
    ///   - bookTitle: 书籍标题。
    ///   - author: 书籍作者。
    ///   - coverFilePath: 封面在共享文件系统中的路径（默认为 `nil`）。
    ///   - bookProgress: 当前阅读进度百分比（默认为 `0`）。
    public init(bookTitle: String, author: String, coverFilePath: String? = nil, bookProgress: Int = 0) {
        self.bookTitle = bookTitle
        self.author = author
        self.coverFilePath = coverFilePath
        self.bookProgress = bookProgress
    }
}
#endif
