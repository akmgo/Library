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
    
    /// ✨ 控制迁移助理弹窗的显示
    @State private var showMigrationSheet: Bool = false
    
    private var backupDirectoryURL: URL {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.akram.library")!
        return container.appendingPathComponent("Backups", isDirectory: true)
    }
    
    var body: some View {
        Form {
            // ================= 1. 云端同步 =================
            Section {
                SettingsControlRow(icon: "icloud.fill", iconColor: .blue, title: "iCloud 同步状态", subtitle: "利用 CloudKit 在你的 Apple 设备间无缝流转数据") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isICloudAvailable ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                            .shadow(color: isICloudAvailable ? Color.green : Color.red, radius: 2)
                        Text(isICloudAvailable ? "已连接并开启" : "未连接 / 未授权")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isICloudAvailable ? .primary : .red)
                    }
                }
            } header: { Text("云端服务").font(.system(size: 13, weight: .bold)) }
            
            // ================= 2. 本地时间机器 =================
            Section {
                SettingsControlRow(icon: "clock.arrow.circlepath", iconColor: .teal, title: "本地无感备份", subtitle: "静默生成高压缩快照，时光倒流防患未然") {
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
            
            // ================= 3. 数据迁移中心 =================
            Section {
                SettingsControlRow(icon: "arrow.triangle.2.circlepath", iconColor: .indigo, title: "数据迁移助理", subtitle: "从微信读书、Kindle 导入，或从历史快照恢复书库") {
                    Button(action: { showMigrationSheet = true }) {
                        Text("开启助理...").font(.system(size: 12, weight: .medium))
                    }
                }
            } header: { Text("数据迁移").font(.system(size: 13, weight: .bold)) }
            
            // ================= 4. 存储管理 =================
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
        .sheet(isPresented: $showMigrationSheet) {
            DataMigrationAssistantView(isPresented: $showMigrationSheet, backupDirectoryURL: backupDirectoryURL, systemMessage: $systemMessage)
        }
    }
    
    // MARK: - iCloud 探针 & 本地快照逻辑
    private func checkICloudStatus() {
        DispatchQueue.main.async { self.isICloudAvailable = FileManager.default.ubiquityIdentityToken != nil }
    }

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
}

// MARK: - 🚀 数据迁移助理 (核心 UI)

enum MigrationSource { case wechat, kindle, appleBooks, backup }
enum MigrationStep { case selection, instructions(MigrationSource), processing(String), success(String), error(String) }

struct DataMigrationAssistantView: View {
    @Binding var isPresented: Bool
    let backupDirectoryURL: URL
    @Binding var systemMessage: AttributedString?
    
    @Environment(\.modelContext) private var modelContext
    @State private var currentStep: MigrationStep = .selection
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            HStack {
                if case .selection = currentStep {} else {
                    Button(action: { withAnimation(.spring) { currentStep = .selection } }) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                    }.buttonStyle(.plain)
                }
                Spacer()
                Text("数据迁移助理")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
            
            Divider()
            
            // 内容路由
            Group {
                switch currentStep {
                case .selection: selectionView
                case .instructions(let source): instructionsView(for: source)
                case .processing(let msg): loadingView(msg: msg)
                case .success(let msg): resultView(isSuccess: true, msg: msg)
                case .error(let msg): resultView(isSuccess: false, msg: msg)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
        .frame(width: 600, height: 580) // ✨ 大幅放大了弹窗尺寸，给顶部和底部留足呼吸空间
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - 1. 选择来源页

    private var selectionView: some View {
        VStack(spacing: 24) {
            Text("请选择你的数据来源")
                .font(.system(size: 20, weight: .bold))
                .padding(.bottom, 8)
            
            // 2x2 网格布局
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    MigrationCard(title: "微信读书", icon: "message.fill", color: .green, desc: "从剪贴板智能抓取导出笔记") {
                        withAnimation(.spring) { currentStep = .instructions(.wechat) }
                    }
                    
                    MigrationCard(title: "Apple Books", icon: "book.pages.fill", color: .orange, desc: "通过系统分享菜单极速导入") {
                        withAnimation(.spring) { currentStep = .instructions(.appleBooks) }
                    }
                }
                
                HStack(spacing: 16) {
                    MigrationCard(title: "Kindle", icon: "book.closed.fill", color: .blue, desc: "解析 My Clippings.txt 文件") {
                        withAnimation(.spring) { currentStep = .instructions(.kindle) }
                    }
                    
                    MigrationCard(title: "本地快照", icon: "clock.arrow.circlepath", color: .indigo, desc: "从 .mlbak 文件满血恢复数据") {
                        withAnimation(.spring) { currentStep = .instructions(.backup) }
                    }
                }
            }
            
            Spacer()
            
            // 底部 Apple Books 专属引导提示
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
                    .padding(.top, 2)
                
                Text("Apple Books 现已打通系统级原生工作流。在苹果图书中阅读时，选中任意摘录，右键点击「分享」->「MyLibrary」，即可直接静默导入，无需在此弹窗操作。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    // MARK: - 2. 专属引导页

    @ViewBuilder
    private func instructionsView(for source: MigrationSource) -> some View {
        VStack(spacing: 24) {
            if source == .wechat {
                Image(systemName: "doc.on.clipboard").font(.system(size: 40)).foregroundColor(.green)
                Text("微信读书剪贴板流").font(.title2.bold())
                Text("请在微信读书 App 中打开任意书籍的笔记，点击「导出 - 复制到剪贴板」，然后点击下方按钮。").multilineTextAlignment(.center).foregroundColor(.secondary)
                            
                Button(action: {
                    currentStep = .processing("正在通过正则引擎解构剪贴板内容...")
                                
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                                    
                        do {
                            let result = try WeChatReadingParser.parseFromClipboard(context: modelContext)
                            NotificationCenter.default.post(name: .libraryDidUpdate, object: nil)
                            currentStep = .success("成功导入《\(result.bookTitle)》\n共提取了 \(result.annotationCount) 条摘录与笔记。")
                        } catch {
                            currentStep = .error(error.localizedDescription)
                        }
                    }
                }) {
                    Text("从剪贴板读取并导入").font(.system(size: 14, weight: .bold)).foregroundColor(.white).padding(.horizontal, 24).padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(Color.green.cornerRadius(8))
                
            } else if source == .appleBooks {
                Image(systemName: "applelogo").font(.system(size: 44)).foregroundColor(.primary)
                Text("原生分享工作流").font(.title2.bold())
                
                VStack(spacing: 14) {
                    Text("1. 在 Mac 或 iPhone 上打开 **Apple Books**。")
                    Text("2. 选中你想摘录的文字，或打开书签列表。")
                    Text("3. 右键点击内容，选择 **分享 (Share)**。")
                    Text("4. 点击 **MyLibrary**，数据即刻静默入库。")
                }
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .padding(.vertical, 8)
                
                Button(action: { isPresented = false }) {
                    Text("我知道了").font(.system(size: 14, weight: .bold)).foregroundColor(.white).padding(.horizontal, 24).padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(Color.primary.cornerRadius(8))
                
            } else if source == .kindle {
                Image(systemName: "cable.connector").font(.system(size: 40)).foregroundColor(.blue)
                Text("Kindle 文本提取").font(.title2.bold())
                Text("请将 Kindle 通过数据线连接至 Mac，在 documents 文件夹中找到并选择 My Clippings.txt 文件。").multilineTextAlignment(.center).foregroundColor(.secondary)
                            
                Button(action: {
                    let panel = NSOpenPanel()
                    panel.title = "选择 My Clippings.txt"
                    panel.allowedContentTypes = [.plainText]
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                                
                    if panel.runModal() == .OK, let fileURL = panel.url {
                        currentStep = .processing("正在逐块读取 Clippings 文件...")
                                    
                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                                        
                            do {
                                let result = try KindleParser.parse(fileURL: fileURL, context: modelContext)
                                NotificationCenter.default.post(name: .libraryDidUpdate, object: nil)
                                currentStep = .success("Kindle 数据解析完毕！\n涉及 \(result.booksCount) 本书籍，共成功导入 \(result.annotationCount) 条摘录与笔记。")
                            } catch {
                                currentStep = .error(error.localizedDescription)
                            }
                        }
                    }
                }) {
                    Text("选择 txt 文件...").font(.system(size: 14, weight: .bold)).foregroundColor(.white).padding(.horizontal, 24).padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(Color.blue.cornerRadius(8))
                
            } else if source == .backup {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundColor(.red)
                Text("危险操作警告").font(.title2.bold())
                Text("从历史快照恢复将彻底抹除并覆盖当前库内的所有数据。请确保你选择了正确的 .mlbak 文件。").multilineTextAlignment(.center).foregroundColor(.secondary)
                
                Button(action: {
                    let panel = NSOpenPanel()
                    panel.title = "选择恢复快照"
                    panel.allowedContentTypes = [UTType.data]
                    panel.directoryURL = backupDirectoryURL
                    if panel.runModal() == .OK, let url = panel.url {
                        performRestoreEngine(url: url)
                    }
                }) {
                    Text("选择 .mlbak 快照并恢复").font(.system(size: 14, weight: .bold)).foregroundColor(.white).padding(.horizontal, 24).padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(Color.red.cornerRadius(8))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - 3. 解析中状态

    private func loadingView(msg: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text(msg).font(.system(size: 14, weight: .medium)).foregroundColor(.secondary)
            Spacer()
        }
    }
    
    // MARK: - 4. 结果页

    private func resultView(isSuccess: Bool, msg: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .font(.system(size: 50))
                .foregroundColor(isSuccess ? .green : .red)
            Text(isSuccess ? "导入成功" : "导入失败").font(.title2.bold())
            Text(msg).foregroundColor(.secondary).multilineTextAlignment(.center)
            Spacer()
            Button("完成") { isPresented = false }
                .buttonStyle(.borderedProminent)
                .tint(isSuccess ? .green : .blue)
        }
    }
    
    // MARK: - 备份恢复底层逻辑

    private func performRestoreEngine(url: URL) {
        currentStep = .processing("正在解压底层 LZFSE 数据...")
        
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
                        let oldRecords = try modelContext.fetch(FetchDescriptor<ReadingRecord>()); oldRecords.forEach { modelContext.delete($0) }
                        let oldAnnos = try modelContext.fetch(FetchDescriptor<BookAnnotation>()); oldAnnos.forEach { modelContext.delete($0) }
                        let oldSnippets = try modelContext.fetch(FetchDescriptor<Snippet>()); oldSnippets.forEach { modelContext.delete($0) }
                        
                        // 重建配置
                        if let cDTO = payload.config { modelContext.insert(UserConfig(dailyReadingGoal: cDTO.dailyReadingGoal, yearlyBookGoal: cDTO.yearlyBookGoal, libraryTargetGoal: cDTO.libraryTargetGoal, updatedAt: cDTO.updatedAt)) }
                        // 重建数据
                        for bDTO in payload.books {
                            modelContext.insert(bDTO.toModel())
                        }
                        for sDTO in payload.snippets {
                            modelContext.insert(sDTO.toModel())
                        }
                        
                        try modelContext.save()
                        WidgetCenter.shared.reloadAllTimelines()
                        NotificationCenter.default.post(name: .libraryDidUpdate, object: nil)
                        
                        currentStep = .success("时光机恢复成功！已为您重建所有书籍与笔记资产。")
                    } catch { currentStep = .error("数据重建失败: \(error.localizedDescription)") }
                }
            } catch { await MainActor.run { currentStep = .error("快照文件已损坏或解压失败") } }
        }
    }
}

/// 🎨 独立的入口卡片组件
private struct MigrationCard: View {
    let title: String
    let icon: String
    let color: Color
    let desc: String
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                    .frame(height: 40)
                
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(16)
            .frame(width: 140, height: 150)
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isHovering ? color.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: isHovering ? 2 : 1))
            .shadow(color: color.opacity(isHovering ? 0.2 : 0), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .onHover { hover in withAnimation(.spring) { isHovering = hover } }
    }
}

// MARK: - 📦 数据传输对象隔离层 (DTOs)

struct BackupPayload: Codable {
    let exportDate: Date
    let config: BackupConfigDTO?
    let books: [BackupBookDTO]
    let snippets: [BackupSnippetDTO]
}

struct BackupConfigDTO: Codable {
    let dailyReadingGoal: Int
    let yearlyBookGoal: Int
    let libraryTargetGoal: Int
    let updatedAt: Date
    
    init(from config: UserConfig) {
        self.dailyReadingGoal = config.dailyReadingGoal
        self.yearlyBookGoal = config.yearlyBookGoal
        self.libraryTargetGoal = config.libraryTargetGoal
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
    let startTime: Date?
    let endTime: Date?
    let progress: Double
    let records: [BackupRecordDTO]
    let annotations: [BackupAnnotationDTO]
    
    init(from book: Book) {
        self.title = book.title
        self.author = book.author
        self.coverData = book.coverData
        self.createdAt = book.createdAt
        self.statusStr = book.status.rawValue
        self.rating = book.rating
        self.tags = book.tags
        self.startTime = book.startTime
        self.endTime = book.endTime
        self.progress = book.progress
        self.records = (book.readingRecords ?? []).map { BackupRecordDTO(from: $0) }
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
            startTime: startTime,
            endTime: endTime,
            progress: progress
        )
        newBook.readingRecords = records.map { $0.toModel(for: newBook) }
        newBook.annotations = annotations.map { $0.toModel(for: newBook) }
        return newBook
    }
}

struct BackupRecordDTO: Codable {
    let date: Date
    let duration: TimeInterval
    
    init(from record: ReadingRecord) {
        self.date = record.date
        self.duration = record.readingDuration
    }

    func toModel(for book: Book) -> ReadingRecord {
        return ReadingRecord(date: date, readingDuration: duration, book: book)
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
