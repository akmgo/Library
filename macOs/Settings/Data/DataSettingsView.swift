#if os(macOS)
import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

struct DataSettingsView: View {
    @Binding var systemMessage: AttributedString?
    @Environment(\.modelContext) private var modelContext
    
    // ================= 状态与存储 =================
    @State private var isICloudAvailable: Bool = false
    @State private var currentCacheSizeMB: Double = 0.0
    
    @AppStorage("enableAutoBackup", store: SharedDatabase.shared.sharedDefaults)
    private var enableAutoBackup: Bool = true
    
    private var backupDirectoryURL: URL {
        // 尝试获取 iCloud Drive 的容器地址
        if let ubiquityURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            // 如果开启了 iCloud Drive，就存在云盘的 MyLibrary 专属文件夹下
            let backupPath = ubiquityURL.appendingPathComponent("Documents").appendingPathComponent("Backups", isDirectory: true)
            return backupPath
        } else {
            // 如果用户没开 iCloud，降级（Fallback）到本地沙盒目录
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            return paths[0].appendingPathComponent("Backups", isDirectory: true)
        }
    }
    
    var body: some View {
        Form {
            // ================= 1. 云端同步 =================
            Section {
                SettingsControlRow(icon: "icloud.fill", iconColor: .blue, title: "iCloud 同步", subtitle: "利用 CloudKit 在所有 Apple 设备间无缝流转数据") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isICloudAvailable ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                            .shadow(color: isICloudAvailable ? Color.green : Color.red, radius: 2)
                        Text(isICloudAvailable ? "已连接" : "未授权")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isICloudAvailable ? .primary : .red)
                    }
                }
            } header: { Text("云端服务").font(.system(size: 13, weight: .bold)) }
            
            // ================= 2. 本地时间机器 =================
            Section {
                SettingsControlRow(icon: "clock.arrow.circlepath", iconColor: .teal, title: "时光机备份", subtitle: "手动生成高压缩快照，文件将自动保存在 iCloud 云盘中") {
                    Toggle("", isOn: $enableAutoBackup)
                        .toggleStyle(.switch)
                        .onChange(of: enableAutoBackup) { _, newValue in
                            if newValue { ensureBackupDirectoryExists() }
                        }
                }
                
                if enableAutoBackup {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("快照存储路径：").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                            Text(backupDirectoryURL.path).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary.opacity(0.8)).lineLimit(2).truncationMode(.middle).textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                        
                        HStack(spacing: 12) {
                            Button(action: revealBackupFolderInFinder) {
                                Label("在 Finder 中打开", systemImage: "folder").font(.system(size: 12, weight: .medium))
                            }
                            
                            Spacer()
                            
                            // ✨ 核心优化：将恢复快照的逻辑直接外提到数据安全中心
                            Button(action: restoreFromBackup) {
                                Text("恢复快照").font(.system(size: 12, weight: .medium)).foregroundColor(.indigo)
                            }
                            
                            Button(action: triggerManualBackup) {
                                Text("立即快照").font(.system(size: 12, weight: .medium))
                            }
                            
                            Button(action: clearAllBackups) {
                                Text("清空历史").font(.system(size: 12, weight: .medium)).foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.leading, 40)
                    .padding(.bottom, 6)
                }
            } header: { Text("数据安全").font(.system(size: 13, weight: .bold)) }
            
            // ================= 3. 存储管理 =================
            Section {
                SettingsControlRow(icon: "trash.fill", iconColor: .gray, title: "清理网络与图片缓存", subtitle: "释放网络图片与接口在内存与磁盘中的临时文件") {
                    HStack(spacing: 12) {
                        Text(String(format: "%.1f MB", currentCacheSizeMB)).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.secondary).frame(width: 60, alignment: .trailing)
                        Button(action: performRealCacheClear) {
                            Text("清理缓存").font(.system(size: 12, weight: .medium))
                        }
                        .disabled(currentCacheSizeMB <= 0.1)
                    }
                }
            } header: { Text("存储管理").font(.system(size: 13, weight: .bold)) }
        }
        .formStyle(.grouped)
        .onAppear {
            checkICloudStatus()
            calculateCacheSize()
            if enableAutoBackup { ensureBackupDirectoryExists() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSUbiquityIdentityDidChange)) { _ in checkICloudStatus() }
    }
    
    // MARK: - iCloud 探针 & 存储逻辑
    
    private func checkICloudStatus() {
        DispatchQueue.main.async { self.isICloudAvailable = FileManager.default.ubiquityIdentityToken != nil }
    }

    private func calculateCacheSize() {
        DispatchQueue.global(qos: .userInitiated).async {
            let memoryCache = URLCache.shared.currentMemoryUsage
            let diskCache = URLCache.shared.currentDiskUsage
            var totalBytes = memoryCache + diskCache
            let tempDir = FileManager.default.temporaryDirectory
            if let tempFiles = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.fileSizeKey]) {
                for fileURL in tempFiles {
                    if let dict = try? fileURL.resourceValues(forKeys: [.fileSizeKey]), let fileSize = dict.fileSize { totalBytes += fileSize }
                }
            }
            let mbSize = Double(totalBytes) / 1024.0 / 1024.0
            DispatchQueue.main.async { self.currentCacheSizeMB = mbSize }
        }
    }

    private func performRealCacheClear() {
        let clearedSize = currentCacheSizeMB
        URLCache.shared.removeAllCachedResponses()
        let tempDir = FileManager.default.temporaryDirectory
        if let tempFiles = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for fileURL in tempFiles {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        calculateCacheSize()
        showToast(String(format: "✨ 清理完成！释放了 %.1f MB 的缓存。", clearedSize))
    }

    private func showToast(_ msg: String) {
        withAnimation { systemMessage = AttributedString(msg) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { systemMessage = nil } }
    }

    // MARK: - 时光机 (备份与恢复) 逻辑
    
    private func ensureBackupDirectoryExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: backupDirectoryURL.path) { try? fm.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true) }
    }

    private func revealBackupFolderInFinder() {
        ensureBackupDirectoryExists()
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: backupDirectoryURL.path)
    }

    private func clearAllBackups() {
        let fm = FileManager.default
        do {
            let files = try fm.contentsOfDirectory(atPath: backupDirectoryURL.path)
            for file in files {
                try fm.removeItem(at: backupDirectoryURL.appendingPathComponent(file))
            }
            showToast("🗑️ 所有历史快照已清空")
        } catch { showToast("❌ 清理失败：\(error.localizedDescription)") }
    }

    private func triggerManualBackup() {
        ensureBackupDirectoryExists()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        let filename = "MyLibrary_\(formatter.string(from: Date())).mlbak"
        let fileURL = backupDirectoryURL.appendingPathComponent(filename)
        
        do {
            let configs = try modelContext.fetch(FetchDescriptor<UserConfig>())
            let books = try modelContext.fetch(FetchDescriptor<Book>())
            let snippets = try modelContext.fetch(FetchDescriptor<Snippet>())
            
            let configDTO = configs.first.map { BackupConfigDTO(from: $0) }
            let bookDTOs = books.map { BackupBookDTO(from: $0) }
            let snippetDTOs = snippets.map { BackupSnippetDTO(from: $0) }
            let payload = BackupPayload(exportDate: Date(), config: configDTO, books: bookDTOs, snippets: snippetDTOs)
            
            showToast("📦 正在压缩生成快照 [\(filename)]...")
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(payload)
            
            Task.detached {
                do {
                    let compressedData = try (jsonData as NSData).compressed(using: .lzfse) as Data
                    try compressedData.write(to: fileURL)
                    await MainActor.run { showToast("✅ 快照生成成功！") }
                } catch { await MainActor.run { showToast("❌ 快照压缩失败: \(error.localizedDescription)") } }
            }
        } catch { showToast("❌ 数据读取或序列化失败: \(error.localizedDescription)") }
    }
    
    // ✨ 核心剥离：直接在设置页触发数据恢复流程
    private func restoreFromBackup() {
        let panel = NSOpenPanel()
        panel.title = "选择恢复快照"
        panel.allowedContentTypes = [UTType.data]
        panel.directoryURL = backupDirectoryURL
        if panel.runModal() == .OK, let url = panel.url {
            performRestoreEngine(url: url)
        }
    }
    
    private func performRestoreEngine(url: URL) {
        showToast("⏳ 正在解压并恢复底层数据...")
        
        Task.detached {
            do {
                let compressedData = try Data(contentsOf: url)
                let jsonData = try (compressedData as NSData).decompressed(using: .lzfse) as Data
                await MainActor.run {
                    do {
                        let payload = try JSONDecoder().decode(BackupPayload.self, from: jsonData)
                        // 暴力清库
                        let oldConfigs = try modelContext.fetch(FetchDescriptor<UserConfig>()); oldConfigs.forEach { modelContext.delete($0) }
                        let oldBooks = try modelContext.fetch(FetchDescriptor<Book>()); oldBooks.forEach { modelContext.delete($0) }
                        let oldRecords = try modelContext.fetch(FetchDescriptor<ReadingSession>()); oldRecords.forEach { modelContext.delete($0) }
                        let oldAnnos = try modelContext.fetch(FetchDescriptor<BookAnnotation>()); oldAnnos.forEach { modelContext.delete($0) }
                        let oldSnippets = try modelContext.fetch(FetchDescriptor<Snippet>()); oldSnippets.forEach { modelContext.delete($0) }
                        
                        // 重建配置
                        if let cDTO = payload.config { modelContext.insert(UserConfig(dailyMinutesGoal: cDTO.dailyMinutesGoal, yearlyBooksGoal: cDTO.yearlyBooksGoal, libraryBooksGoal: cDTO.libraryBooksGoal, updatedAt: cDTO.updatedAt)) }
                        // 重建数据
                        for bDTO in payload.books { modelContext.insert(bDTO.toModel()) }
                        for sDTO in payload.snippets { modelContext.insert(sDTO.toModel()) }
                        
                        try modelContext.save()
                        WidgetCenter.shared.reloadAllTimelines()
                        
                        showToast("✅ 时光机恢复成功！已为您重建所有书籍与笔记资产。")
                    } catch { showToast("❌ 数据重建失败: \(error.localizedDescription)") }
                }
            } catch { await MainActor.run { showToast("❌ 快照文件已损坏或解压失败") } }
        }
    }
}

// MARK: - 📦 数据传输对象隔离层 (DTOs) 必须保留以支持备份与恢复

struct BackupPayload: Codable {
    let exportDate: Date
    let config: BackupConfigDTO?
    let books: [BackupBookDTO]
    let snippets: [BackupSnippetDTO]
}

struct BackupConfigDTO: Codable {
    let dailyMinutesGoal: Int
    let yearlyBooksGoal: Int
    let libraryBooksGoal: Int
    let updatedAt: Date
    
    init(from config: UserConfig) {
        self.dailyMinutesGoal = config.dailyMinutesGoal
        self.yearlyBooksGoal = config.yearlyBooksGoal
        self.libraryBooksGoal = config.libraryBooksGoal
        self.updatedAt = config.updatedAt
    }
}

struct BackupBookDTO: Codable {
    let title: String
    let author: String
    let coverData: Data?
    let createdAt: Date
    let statusStr: String
    let rating: Int
    let tags: [String]
    let startDate: Date?
    let finishDate: Date?
    let progress: Double
    let annotations: [BackupAnnotationDTO]
    
    init(from book: Book) {
        self.title = book.title
        self.author = book.author
        self.coverData = book.coverData
        self.createdAt = book.createdAt
        self.statusStr = book.status.rawValue
        self.rating = book.rating
        self.tags = book.tags
        self.startDate = book.startDate
        self.finishDate = book.finishDate
        self.progress = book.progressRatio
        self.annotations = (book.annotations ?? []).map { BackupAnnotationDTO(from: $0) }
    }
    
    func toModel() -> Book {
        let parsedStatus = BookStatus(rawValue: statusStr) ?? .unread
        let newBook = Book(
            title: title,
            author: author,
            coverData: coverData,
            createdAt: createdAt,
            status: parsedStatus,
            rating: rating,
            tags: tags,
            startDate: startDate,
            finishDate: finishDate,
            progressUnit: .percent,
            totalAmount: 100,
            currentAmount: progress * 100
        )
        newBook.annotations = annotations.map { $0.toModel(for: newBook) }
        return newBook
    }
}

struct BackupSessionDTO: Codable {
    let date: Date
    let duration: TimeInterval
    
    init(from record: ReadingSession) {
        self.date = record.date
        self.duration = record.duration
    }
}

struct BackupAnnotationDTO: Codable {
    let typeStr: String
    let content: String
    let createdAt: Date
    
    init(from annotation: BookAnnotation) {
        self.typeStr = annotation.type.rawValue
        self.content = annotation.content
        self.createdAt = annotation.createdAt
    }

    func toModel(for book: Book) -> BookAnnotation {
        let parsedType = AnnotationType(rawValue: typeStr) ?? .excerpt
        return BookAnnotation(content: content, type: parsedType, createdAt: createdAt, book: book)
    }
}

struct BackupSnippetDTO: Codable {
    let title: String
    let content: String
    let author: String
    let dynasty: String
    let annotation: String
    let categoryStr: String
    let addedDate: Date
    
    init(from snippet: Snippet) {
        self.title = snippet.title
        self.content = snippet.content
        self.author = snippet.author
        self.dynasty = snippet.dynasty
        self.annotation = snippet.annotation
        self.categoryStr = snippet.category.rawValue
        self.addedDate = snippet.addedDate
    }
    
    func toModel() -> Snippet {
        let parsedCategory = SnippetCategory(rawValue: categoryStr) ?? .web
        let newSnippet = Snippet(
            title: title,
            content: content,
            author: author,
            dynasty: dynasty,
            annotation: annotation,
            category: parsedCategory
        )
        newSnippet.addedDate = addedDate
        return newSnippet
    }
}
#endif
