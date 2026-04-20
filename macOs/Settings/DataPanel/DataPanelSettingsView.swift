#if os(macOS)
import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 定义文件选择器当前期待处理的底层数据类型。
enum ImportType { case book, excerpt, note, record }

// MARK: - ✨ 高级数据管家 (主容器)

/// macOS 设置中的“数据面板”主视图容器。
///
/// **架构设计：**
/// 采用了 `Extension` 物理文件拆分法。
/// 本文件仅包含状态变量 (`@State`) 和最顶层的 `Form` 框架与 `fileImporter` 弹窗挂载。
/// UI 的具体构建和数据的具体处理逻辑，分别由对应的扩展文件接管。
struct DataPanelSettingsView: View {
    @Environment(\.modelContext) internal var modelContext
    @Query internal var allBooks: [Book]
    
    @Binding var systemMessage: AttributedString?
    @ObservedObject internal var syncEngine = SyncEngine.shared
    @ObservedObject internal var importer = AppleBooksImporter.shared
    
    /// 隐藏焦点接收器，阻断 SwiftUI 列表的默认焦点抢占
    @FocusState internal var dummyFocus: Bool
    
    // MARK: - I/O 拾取器状态
    @State internal var activeImportType: ImportType = .book
    @State internal var isShowingJSONPicker = false
    @State internal var showCoverPicker = false
    @State internal var showExcerptPicker = false
    @State internal var showNotePicker = false
    @State internal var showRecordPicker = false
    
    // MARK: - JSON 反序列化暂存池
    @State internal var pendingBooks: [BookImportDTO] = []
    @State internal var matchedCovers: [String: Data] = [:]
    @State internal var pendingExcerpts: [ExcerptImportDTO] = []
    @State internal var pendingNotes: [NoteImportDTO] = []
    @State internal var pendingRecords: [ReadingRecordImportDTO] = []
    
    // MARK: - 轨迹生成器状态
    @State internal var selectedBookIDForRecord: String = ""
    @State internal var recordStartDate: Date = .init()
    @State internal var recordEndDate: Date = .init()
    
    @State internal var isExporting = false
    
    // MARK: - 危险区操作状态
    @State internal var showingDeleteAlert = false
    @State internal var showingDeleteSelectionSheet = false
    @State internal var booksToDelete: Set<String> = []

    internal var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder
    }
    
    var body: some View {
        Form {
            importSection
            exportSection
            syncSection
            dangerSection
        }
        .formStyle(.grouped)
        .padding()
        // 捕获焦点防止列表误触
        .background(Color.clear.frame(width: 0, height: 0).focused($dummyFocus).onAppear { dummyFocus = true })
        // 图层级隔离的所有文件选择器
        .background(Color.clear.fileImporter(isPresented: $isShowingJSONPicker, allowedContentTypes: [.json]) { handleJSONImport(result: $0, type: activeImportType) })
        .background(Color.clear.fileImporter(isPresented: $showCoverPicker, allowedContentTypes: [.image], allowsMultipleSelection: true) { handleCoverImport(result: $0) })
        .background(Color.clear.fileImporter(isPresented: $showExcerptPicker, allowedContentTypes: [.json]) { handleJSONImport(result: $0, type: .excerpt) })
        .background(Color.clear.fileImporter(isPresented: $showNotePicker, allowedContentTypes: [.json]) { handleJSONImport(result: $0, type: .note) })
        .background(Color.clear.fileImporter(isPresented: $showRecordPicker, allowedContentTypes: [.json]) { handleJSONImport(result: $0, type: .record) })
        
        .alert("确定要清空所有数据吗？", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("确认清空", role: .destructive) { deleteAllLocalData() }
        } message: {
            Text("所有的书籍档案、摘录金句和阅读轨迹将被永久删除，此操作不可逆转！")
        }
        // 选择性删除的表单抽屉
        .sheet(isPresented: $showingDeleteSelectionSheet) {
            DeleteSelectionSheet(
                allBooks: allBooks,
                selectedBookIDs: $booksToDelete,
                onCancel: { showingDeleteSelectionSheet = false },
                onConfirm: { showingDeleteSelectionSheet = false; executeSelectiveDeletion() }
            )
        }
    }
}
#endif
