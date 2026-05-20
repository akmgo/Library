#if os(iOS)
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

// MARK: - 🗄️ 3. 数据与安全页 (iOS 适配版双端互通时光机)

struct MobileDataSettingsView: View {
    @Binding var systemMessage: AttributedString?
    @Environment(\.modelContext) private var modelContext
    
    @State private var isICloudAvailable: Bool = false
    @State private var currentCacheSizeMB: Double = 0.0
    @State private var showFileImporter: Bool = false
    
    @AppStorage("enableAutoBackup", store: SharedDatabase.shared.sharedDefaults)
    private var enableAutoBackup: Bool = true
    
    // ✨ 核心机制：iOS/macOS 双端互通的 iCloud 备份目录
    private var backupDirectoryURL: URL {
        if let ubiquityURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            // 存放到云盘 Documents 下，使用户能在 "文件" App 中跨设备看到它
            return ubiquityURL.appendingPathComponent("Documents").appendingPathComponent("Backups", isDirectory: true)
        } else {
            // 降级：未开启 iCloud 时保存在本地沙盒
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            return paths[0].appendingPathComponent("Backups", isDirectory: true)
        }
    }
    
    var body: some View {
        Form {
            // ================= 1. 云端同步 =================
            Section {
                MobileDataInlineRow(icon: "icloud.fill", iconColor: .blue, title: "iCloud 同步", subtitle: "利用 CloudKit 在所有 Apple 设备间无缝流转数据") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isICloudAvailable ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(isICloudAvailable ? "已连接" : "未授权")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isICloudAvailable ? .primary : .red)
                    }
                }
            } header: { Text("云端服务") }
            
            // ================= 2. 时间机器 =================
            Section {
                MobileDataInlineRow(icon: "clock.arrow.circlepath", iconColor: .teal, title: "时光机备份", subtitle: "手动生成高压缩快照，文件将自动保存在 iCloud 云盘中") {
                    Toggle("", isOn: $enableAutoBackup).labelsHidden()
                }
                .onChange(of: enableAutoBackup) { _, newValue in
                    if newValue { ensureBackupDirectoryExists() }
                }
                
                if enableAutoBackup {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("快照文件将安全地存储在系统的「文件」App 中，可跨设备恢复。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        // ✨ 独立的 3 个并排操作按钮，带各自独立边框与底色
                        HStack(spacing: 12) {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showFileImporter = true
                            }) {
                                Text("恢复快照")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.indigo)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.indigo.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                triggerManualBackup()
                            }) {
                                Text("立即快照")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                clearAllBackups()
                            }) {
                                Text("清空历史")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                    .padding(.bottom, 6)
                }
            } header: { Text("时间机器") }
            
            // ================= 3. 存储管理 =================
            Section {
                MobileDataInlineRow(icon: "trash.fill", iconColor: .gray, title: "清理缓存", subtitle: "释放网络图片与接口在内存与磁盘中的临时文件") {
                    // ✨ 优化：垂直布局对齐，且按钮样式 1:1 统一“清空历史”按钮
                    VStack(alignment: .trailing, spacing: 10) {
                        Text(String(format: "%.1f MB", currentCacheSizeMB))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Button(action: performRealCacheClear) {
                            Text("清理缓存")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(currentCacheSizeMB <= 0.1 ? .secondary : .red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(currentCacheSizeMB <= 0.1 ? Color(uiColor: .tertiarySystemGroupedBackground) : Color.red.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: { Text("存储管理") }
        }
        .navigationTitle("数据与安全")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkICloudStatus()
            calculateCacheSize()
            if enableAutoBackup { ensureBackupDirectoryExists() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSUbiquityIdentityDidChange)) { _ in checkICloudStatus() }
        // iOS 原生安全文件选择器 (跨出沙盒读取 iCloud)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [UTType.data]) { result in
            switch result {
            case .success(let url):
                // 必须使用 SecurityScopedResource 获取外部文件权限
                guard url.startAccessingSecurityScopedResource() else {
                    showToast("❌ 无法获取快照文件的访问权限")
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                performRestoreEngine(url: url)
            case .failure(let error):
                showToast("❌ 文件选择失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - iCloud 探针 & 存储清理逻辑
    
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let clearedSize = currentCacheSizeMB
        
        URLCache.shared.removeAllCachedResponses()
        let tempDir = FileManager.default.temporaryDirectory
        if let tempFiles = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for fileURL in tempFiles { try? FileManager.default.removeItem(at: fileURL) }
        }
        
        calculateCacheSize()
        showToast(String(format: "✨ 释放了 %.1f MB 缓存", clearedSize))
    }

    private func showToast(_ msg: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation { systemMessage = AttributedString(msg) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { systemMessage = nil } }
    }

    // MARK: - iOS 适配版备份恢复引擎
    
    private func ensureBackupDirectoryExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: backupDirectoryURL.path) {
            try? fm.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func clearAllBackups() {
        let fm = FileManager.default
        do {
            let files = try fm.contentsOfDirectory(atPath: backupDirectoryURL.path)
            for file in files { try fm.removeItem(at: backupDirectoryURL.appendingPathComponent(file)) }
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
            
            showToast("📦 正在生成快照...")
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(payload)
            
            Task.detached {
                do {
                    let compressedData = try (jsonData as NSData).compressed(using: .lzfse) as Data
                    try compressedData.write(to: fileURL)
                    await MainActor.run { showToast("✅ 快照已生成至 iCloud Drive") }
                } catch { await MainActor.run { showToast("❌ 快照压缩失败") } }
            }
        } catch { showToast("❌ 数据序列化失败") }
    }
    
    private func performRestoreEngine(url: URL) {
        showToast("⏳ 正在解压数据并重建数据库...")
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
                        showToast("✅ 时光机恢复成功！")
                    } catch { showToast("❌ 数据重建失败: \(error.localizedDescription)") }
                }
            } catch { await MainActor.run { showToast("❌ 快照文件损坏或无法读取") } }
        }
    }
}

// MARK: - 🎨 专属布局原子组件：支持文字自动换行、顶部对齐

struct MobileDataInlineRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let control: Content
    
    var body: some View {
        // ✨ 核心修复：强制设置为顶部对齐 (.top) 避免长文字换行导致的居中悬空
        HStack(alignment: .top, spacing: 12) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(iconColor).frame(width: 28, height: 28)
                Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
            }
            .padding(.top, 2) // ✨ 视觉微调
            
            // 文案 (支持自动换行)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 8)
            
            // 控件靠右
            control
        }
        .padding(.vertical, 6)
    }
}

// MARK: - 📦 跨端统一的数据传输对象层 (DTOs)

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
            title: title, author: author, coverData: coverData,
            createdAt: createdAt, status: parsedStatus, rating: rating,
            tags: tags, startDate: startDate, finishDate: finishDate,
            progressUnit: .percent, totalAmount: 100, currentAmount: progress * 100
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
            title: title, content: content, author: author,
            dynasty: dynasty, annotation: annotation, category: parsedCategory
        )
        newSnippet.addedDate = addedDate
        return newSnippet
    }
}
#endif
