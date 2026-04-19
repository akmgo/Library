#if os(macOS)
import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum ImportType { case book, excerpt, note, record }

struct DataPanelSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var allBooks: [Book]
    
    @Binding var systemMessage: AttributedString?
    @ObservedObject private var syncEngine = SyncEngine.shared
    @ObservedObject private var importer = AppleBooksImporter.shared
    
    /// 隐藏焦点接收器
    @FocusState private var dummyFocus: Bool
    
    // 文件选择器状态
    @State private var activeImportType: ImportType = .book
    @State private var isShowingJSONPicker = false
    @State private var showCoverPicker = false
    @State private var showExcerptPicker = false
    @State private var showNotePicker = false
    @State private var showRecordPicker = false
    
    // 数据缓存
    @State private var pendingBooks: [BookImportDTO] = []
    @State private var matchedCovers: [String: Data] = [:]
    @State private var pendingExcerpts: [ExcerptImportDTO] = []
    @State private var pendingNotes: [NoteImportDTO] = []
    @State private var pendingRecords: [ReadingRecordImportDTO] = []
    
    // 手动轨迹生成器状态
    @State private var selectedBookIDForRecord: String = ""
    @State private var recordStartDate: Date = .init()
    @State private var recordEndDate: Date = .init()
    
    /// ✨ 导出状态
    @State private var isExporting = false
    
    // 危险区状态
    @State private var showingDeleteAlert = false
    @State private var showingDeleteSelectionSheet = false
    @State private var booksToDelete: Set<String> = []

    private var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder
    }
    
    var body: some View {
        Form {
            // ================= 1. 数据导入区块 =================
            Section {
                // 书籍导入
                VStack(alignment: .leading, spacing: 12) {
                    SettingsHeaderRow(icon: "book.closed.fill", iconColor: .blue, title: "书籍与封面导入", subtitle: "批量匹配并导入您的书籍元数据与高清封面")
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 10) {
                            Button(action: { activeImportType = .book; isShowingJSONPicker = true }) {
                                Text(pendingBooks.isEmpty ? "选择图书" : "已选 \(pendingBooks.count) 本图书").frame(width: 140)
                            }
                            Button(action: { showCoverPicker = true }) {
                                Text(matchedCovers.isEmpty ? "选择封面" : "已选 \(matchedCovers.count) 张封面").frame(width: 140)
                            }
                        }
                        Spacer()
                        Button(action: executeBookImport) {
                            Text("开始导入").bold().padding(.horizontal, 12).padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent).tint(.blue).disabled(pendingBooks.isEmpty)
                    }.padding(.leading, 44)
                }.padding(.vertical, 8)
                
                // 摘录导入
                VStack(alignment: .leading, spacing: 12) {
                    SettingsHeaderRow(icon: "quote.opening", iconColor: .orange, title: "摘录导入", subtitle: "从外部文件导入您的灵感摘录")
                    HStack {
                        Button(action: { activeImportType = .excerpt; showExcerptPicker = true }) {
                            Text(pendingExcerpts.isEmpty ? "选择摘录" : "已选 \(pendingExcerpts.count) 条摘录").frame(width: 140)
                        }
                        Spacer()
                        Button(action: executeExcerptImport) {
                            Text("开始导入").bold().padding(.horizontal, 12).padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent).tint(.orange).disabled(pendingExcerpts.isEmpty)
                    }.padding(.leading, 44)
                }.padding(.vertical, 8)
                
                // 笔记导入
                VStack(alignment: .leading, spacing: 12) {
                    SettingsHeaderRow(icon: "highlighter", iconColor: .purple, title: "笔记导入", subtitle: "批量导入您的结构化读书笔记")
                    HStack {
                        Button(action: { activeImportType = .note; showNotePicker = true }) {
                            Text(pendingNotes.isEmpty ? "选择笔记" : "已选 \(pendingNotes.count) 条笔记").frame(width: 140)
                        }
                        Spacer()
                        Button(action: executeNoteImport) {
                            Text("开始导入").bold().padding(.horizontal, 12).padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent).tint(.purple).disabled(pendingNotes.isEmpty)
                    }.padding(.leading, 44)
                }.padding(.vertical, 8)
                
                // 外部轨迹导入
                VStack(alignment: .leading, spacing: 12) {
                    SettingsHeaderRow(icon: "clock.arrow.circlepath", iconColor: .cyan, title: "外部轨迹导入", subtitle: "批量导入并智能匹配指定书籍的历史阅读记录 (JSON)")
                    HStack {
                        Button(action: { activeImportType = .record; showRecordPicker = true }) {
                            Text(pendingRecords.isEmpty ? "选择历史轨迹" : "已选 \(pendingRecords.count) 天记录").frame(width: 140)
                        }
                        Spacer()
                        Button(action: executeRecordImport) {
                            Text("开始导入").bold().padding(.horizontal, 12).padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent).tint(.cyan).disabled(pendingRecords.isEmpty)
                    }.padding(.leading, 44)
                }.padding(.vertical, 8)
                
                // 轨迹生成器 (手动补录)
                VStack(alignment: .leading, spacing: 16) {
                    SettingsHeaderRow(icon: "calendar.badge.plus", iconColor: .mint, title: "手动轨迹补录", subtitle: "为指定书籍批量生成连贯的阅读轨迹")
                    VStack(spacing: 12) {
                        HStack {
                            Text("选择书籍").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary)
                            Spacer()
                            Picker("", selection: $selectedBookIDForRecord) {
                                Text("选择一本书").tag("")
                                Divider()
                                ForEach(allBooks) { book in Text(book.title ?? "未知").tag(book.id ?? "") }
                            }
                            .labelsHidden().pickerStyle(.menu)
                            .frame(width: 150)
                            .padding(.horizontal, 8).padding(.vertical, 6)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                        }
                        Divider().opacity(0.5)
                        HStack {
                            Text("开始日期").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary)
                            Spacer()
                            DatePicker("", selection: $recordStartDate, displayedComponents: .date)
                                .labelsHidden().datePickerStyle(.stepperField)
                                .frame(width: 150)
                                .padding(.horizontal, 8).padding(.vertical, 6)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(6)
                        }
                        Divider().opacity(0.5)
                        HStack {
                            Text("结束日期").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary)
                            Spacer()
                            DatePicker("", selection: $recordEndDate, displayedComponents: .date)
                                .labelsHidden().datePickerStyle(.stepperField)
                                .frame(width: 150)
                                .padding(.horizontal, 8).padding(.vertical, 6)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(6)
                        }
                        Button(action: generateManualRecords) {
                            HStack {
                                Spacer()
                                Image(systemName: "sparkles")
                                Text("开始生成阅读记录")
                                Spacer()
                            }
                            .font(.system(size: 13, weight: .bold)).padding(.vertical, 8)
                            .background(selectedBookIDForRecord.isEmpty || recordStartDate > recordEndDate ? Color.gray : Color.mint)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedBookIDForRecord.isEmpty || recordStartDate > recordEndDate)
                        .padding(.top, 4)
                    }.padding(.leading, 44)
                }.padding(.vertical, 8)
                
            } header: { Text("数据导入").font(.system(size: 16, weight: .bold)).padding(.bottom, 6) }
            .padding(.bottom, 16)
            
            // ================= 2. 数据导出区块 =================
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsHeaderRow(icon: "square.and.arrow.up.fill", iconColor: .indigo, title: "数据备份与导出", subtitle: "将所有书籍、摘录、笔记及封面图片导出为结构化的开放 JSON 文件夹，完全保障您的数据主权")
                    HStack {
                        Spacer()
                        Button(action: executeDataExport) {
                            HStack {
                                if isExporting { ProgressView().controlSize(.small).padding(.trailing, 4) }
                                Text(isExporting ? "正在导出..." : "立刻导出全部数据").bold().padding(.horizontal, 12).padding(.vertical, 4)
                            }
                        }
                        .buttonStyle(.borderedProminent).tint(.indigo).disabled(isExporting || allBooks.isEmpty)
                    }.padding(.leading, 44)
                }.padding(.vertical, 8)
            } header: { Text("数据导出").font(.system(size: 16, weight: .bold)).padding(.bottom, 6) }
            .padding(.bottom, 16)
            
            // ================= 3. 数据同步区块 =================
            Section {
                HStack(spacing: 16) {
                    SettingsHeaderRow(icon: "arrow.triangle.2.circlepath", iconColor: .green, title: "Apple Books 数据穿透同步", subtitle: "自动抓取并同步 Apple Books 的阅读进度与原生摘录")
                    Spacer()
                    Button(action: executeFullAppleBooksMigration) {
                        Text(importer.isImporting ? "同步中..." : "立刻同步").bold().padding(.horizontal, 12).padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent).tint(.green).disabled(importer.isImporting)
                }.padding(.vertical, 8)
            } header: { Text("Apple 生态对接").font(.system(size: 16, weight: .bold)).padding(.bottom, 6) }
            .padding(.bottom, 16)
            
            // ================= 4. 危险操作区 =================
            Section {
                HStack(spacing: 16) {
                    SettingsHeaderRow(icon: "trash.slash.fill", iconColor: .gray, title: "删除指定数据", subtitle: "选择性清理多余的书籍、笔记或失效的阅读记录")
                    Spacer()
                    Button("选择清理") { booksToDelete.removeAll(); showingDeleteSelectionSheet = true }
                }.padding(.vertical, 8)
                
                HStack(spacing: 16) {
                    SettingsHeaderRow(icon: "exclamationmark.triangle.fill", iconColor: .red, title: "抹除全部数据", subtitle: "警告：此操作将清空库中所有内容，且不可恢复")
                    Spacer()
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Text("抹除数据").foregroundColor(.red)
                    }
                }.padding(.vertical, 8)
            } header: { Text("危险区").font(.system(size: 16, weight: .bold)).foregroundColor(.red).padding(.bottom, 6) }
        }
        .formStyle(.grouped)
        .padding()
        .background(Color.clear.frame(width: 0, height: 0).focused($dummyFocus).onAppear { dummyFocus = true })
        // 图层隔离的文件选择器
        .background(Color.clear.fileImporter(isPresented: $isShowingJSONPicker, allowedContentTypes: [.json]) { handleJSONImport(result: $0, type: activeImportType) })
        .background(Color.clear.fileImporter(isPresented: $showCoverPicker, allowedContentTypes: [.image], allowsMultipleSelection: true) { handleCoverImport(result: $0) })
        .background(Color.clear.fileImporter(isPresented: $showExcerptPicker, allowedContentTypes: [.json]) { handleJSONImport(result: $0, type: .excerpt) })
        .background(Color.clear.fileImporter(isPresented: $showNotePicker, allowedContentTypes: [.json]) { handleJSONImport(result: $0, type: .note) })
        .background(Color.clear.fileImporter(isPresented: $showRecordPicker, allowedContentTypes: [.json]) { handleJSONImport(result: $0, type: .record) })
        .alert("确定要清空所有数据吗？", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("确认清空", role: .destructive) { deleteAllLocalData() }
        } message: { Text("所有的书籍档案、摘录金句和阅读轨迹将被永久删除，此操作不可逆转！") }
        .sheet(isPresented: $showingDeleteSelectionSheet) {
            DeleteSelectionSheet(
                allBooks: allBooks,
                selectedBookIDs: $booksToDelete,
                onCancel: { showingDeleteSelectionSheet = false },
                onConfirm: { showingDeleteSelectionSheet = false; executeSelectiveDeletion() }
            )
        }
    }
    
    // MARK: - ✨ 一键穿透搬家与封面自动装配引擎

    private func executeFullAppleBooksMigration() {
        showPlainFeedback("🚀 正在穿透抓取 Apple Books 全量数据...")
        Task {
            await importer.performFullMigration(modelContext: modelContext, existingBooks: allBooks) {
                showCoverPicker = true
            }
        }
    }

    private func handleCoverImport(result: Result<[URL], Error>) {
        guard let urls = try? result.get(), !urls.isEmpty else {
            showPlainFeedback("⚠️ 封面选择已跳过。")
            return
        }
        var tempCovers: [String: Data] = [:]
        var updatedDBCount = 0
            
        for url in urls {
            if url.startAccessingSecurityScopedResource() {
                let bookTitle = url.deletingPathExtension().lastPathComponent
                if let data = try? Data(contentsOf: url) {
                    tempCovers[bookTitle] = data
                    if let existingBook = allBooks.first(where: { $0.title == bookTitle }) {
                        existingBook.coverData = data
                        updatedDBCount += 1
                    }
                }
                url.stopAccessingSecurityScopedResource()
            }
        }
            
        DispatchQueue.main.async {
            self.matchedCovers = tempCovers
            if updatedDBCount > 0 {
                try? self.modelContext.save()
                var log = AttributedString("🎉 完美！成功自动装配了 ")
                var countStr = AttributedString("\(updatedDBCount)"); countStr.foregroundColor = .green; countStr.font = .system(size: 14, weight: .bold)
                log.append(countStr); log.append(AttributedString(" 张高清封面！"))
                self.showRichFeedback(log)
            } else {
                self.showPlainFeedback("⚠️ 成功读取图片，但图片名未能与本地书名匹配上。")
            }
        }
    }
    
    private func executeDataExport() {
        isExporting = true
        showPlainFeedback("📦 正在打包导出数据，请稍候...")
        Task {
            do {
                if let destinationURL = try await DataExportService.shared.exportBooks(allBooks) {
                    DispatchQueue.main.async {
                        var log = AttributedString("✅ 导出成功！已保存至：")
                        var folderName = AttributedString(destinationURL.lastPathComponent); folderName.foregroundColor = .indigo; folderName.font = .system(size: 13, weight: .bold)
                        log.append(folderName)
                        self.showRichFeedback(log)
                        self.isExporting = false
                        NSWorkspace.shared.open(destinationURL)
                    }
                } else {
                    DispatchQueue.main.async { self.isExporting = false }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showPlainFeedback("❌ 导出失败：\(error.localizedDescription)")
                    self.isExporting = false
                }
            }
        }
    }
    
    private func executeSelectiveDeletion() {
        var deletedCount = 0
        for bookID in booksToDelete {
            if let book = allBooks.first(where: { $0.id == bookID }) { modelContext.delete(book); deletedCount += 1 }
        }
        do {
            try modelContext.save()
            var log = AttributedString("🗑️ 成功清理了 ")
            var countStr = AttributedString("\(deletedCount)"); countStr.foregroundColor = .red; countStr.font = .system(size: 14, weight: .bold)
            log.append(countStr); log.append(AttributedString(" 本书籍及其所有的关联数据。"))
            showRichFeedback(log)
            booksToDelete.removeAll()
        } catch { showPlainFeedback("❌ 清理失败，请检查数据库状态。") }
    }
    
    private func deleteAllLocalData() {
        do { try modelContext.delete(model: Book.self); try modelContext.delete(model: Excerpt.self); try modelContext.delete(model: Note.self); try modelContext.delete(model: ReadingRecord.self); try modelContext.save(); showPlainFeedback("🗑️ 本地所有数据已彻底清空。") } catch { showPlainFeedback("❌ 清空数据失败") }
    }
    
    private func handleJSONImport(result: Result<URL, Error>, type: ImportType) {
        guard let url = try? result.get() else { return }
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                switch type {
                case .book:
                    let items = try jsonDecoder.decode([BookImportDTO].self, from: data)
                    DispatchQueue.main.async { self.pendingBooks = items; self.showPlainFeedback("📚 成功解析 \(items.count) 本书籍配置。") }
                case .excerpt:
                    let items = try jsonDecoder.decode([ExcerptImportDTO].self, from: data)
                    DispatchQueue.main.async { self.pendingExcerpts = items; self.showPlainFeedback("🔖 成功解析 \(items.count) 条摘录。") }
                case .note:
                    let items = try jsonDecoder.decode([NoteImportDTO].self, from: data)
                    DispatchQueue.main.async { self.pendingNotes = items; self.showPlainFeedback("📝 成功解析 \(items.count) 条笔记。") }
                case .record:
                    let items = try jsonDecoder.decode([ReadingRecordImportDTO].self, from: data)
                    DispatchQueue.main.async { self.pendingRecords = items; self.showPlainFeedback("📅 成功解析 \(items.count) 条阅读轨迹。") }
                }
            } catch { showPlainFeedback("❌ JSON 格式解析失败") }
        }
    }
    
    private func executeRecordImport() {
        var count = 0
        let calendar = Calendar.current
        for dto in pendingRecords {
            guard let title = dto.bookTitle, let targetBook = allBooks.first(where: { $0.title == title }) else { continue }
            let finalDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dto.date) ?? dto.date
            
            // ✨ 修复：从 reading_record 改为了 readingRecords
            let existingRecords = targetBook.readingRecords ?? []
            let exists = existingRecords.contains { record in calendar.isDate(record.date ?? Date(), inSameDayAs: finalDate) }
            
            if !exists {
                let newRecord = ReadingRecord(date: finalDate, book: targetBook)
                if let duration = dto.duration { newRecord.readingDuration = duration } else { newRecord.readingDuration = Double(Int.random(in: 1200 ... 4200)) }
                modelContext.insert(newRecord)
                if targetBook.readingRecords == nil { targetBook.readingRecords = [] }
                targetBook.readingRecords?.append(newRecord)
                count += 1
            }
        }
            
        do {
            try modelContext.save()
            var log = AttributedString("✅ 导入成功！共入库 ")
            var countStr = AttributedString("\(count)"); countStr.foregroundColor = .cyan
            log.append(countStr); log.append(AttributedString(" 天历史轨迹。"))
            showRichFeedback(log)
            pendingRecords.removeAll()
        } catch {
            showPlainFeedback("❌ 写入失败，请检查数据库状态。")
        }
    }
    
    private func executeBookImport() {
        var count = 0; var matchedCount = 0; var skippedCount = 0; var unmatchedTitles: [String] = []
        let existingTitles = Set(allBooks.compactMap { $0.title })
            
        for dto in pendingBooks {
            if existingTitles.contains(dto.title) { skippedCount += 1; continue }
            let cover = matchedCovers[dto.title]
            if cover != nil { matchedCount += 1 } else { unmatchedTitles.append(dto.title) }
            
            // ✨ 修复：使用原始值转换为枚举，带安全回退
            let fallbackStatus = BookStatus(rawValue: dto.status ?? "UNREAD") ?? .unread
            let newBook = Book(title: dto.title, author: dto.author, coverData: cover, status: fallbackStatus, rating: dto.rating ?? 0, tags: dto.tags ?? [], startTime: dto.startTime, endTime: dto.endTime, progress: dto.progress ?? 0, isWantToRead: dto.isWantToRead ?? false)
            
            modelContext.insert(newBook)
            count += 1
        }
            
        do {
            try modelContext.save()
            var log = AttributedString("🎉 导入完毕！新增 "); var countStr = AttributedString("\(count)"); countStr.foregroundColor = .cyan
            log.append(countStr); log.append(AttributedString(" 本。其中 ")); var matchedStr = AttributedString("\(matchedCount)"); matchedStr.foregroundColor = .green
            log.append(matchedStr); log.append(AttributedString(" 本配对封面。"))
            if skippedCount > 0 { var skipStr = AttributedString(" 拦截重复 \(skippedCount) 本。"); skipStr.foregroundColor = .gray; log.append(skipStr) }
            if !unmatchedTitles.isEmpty { var warnStr = AttributedString("⚠️ 缺封面: \(unmatchedTitles.count)本"); warnStr.foregroundColor = .orange; log.append(warnStr) }
            showRichFeedback(log); pendingBooks.removeAll(); matchedCovers.removeAll()
        } catch { showPlainFeedback("❌ 写入失败") }
    }
    
    private func executeExcerptImport() {
        var count = 0
        for dto in pendingExcerpts {
            let targetBook = allBooks.first(where: { $0.title == dto.bookTitle })
            let newExcerpt = Excerpt(content: dto.content, createdAt: dto.createdAt ?? Date(), book: targetBook)
            modelContext.insert(newExcerpt)
            if let tb = targetBook { if tb.excerpts == nil { tb.excerpts = [] }; tb.excerpts?.append(newExcerpt) }
            count += 1
        }
        try? modelContext.save()
        var log = AttributedString("✅ 导入成功！共入库 "); var countStr = AttributedString("\(count)"); countStr.foregroundColor = .orange
        log.append(countStr); log.append(AttributedString(" 条摘录。"))
        showRichFeedback(log); pendingExcerpts.removeAll()
    }
    
    private func executeNoteImport() {
        var count = 0
        for dto in pendingNotes {
            let targetBook = allBooks.first(where: { $0.title == dto.bookTitle })
            let newNote = Note(content: dto.content, createdAt: dto.createdAt ?? Date(), book: targetBook)
            modelContext.insert(newNote)
            if let tb = targetBook { if tb.notes == nil { tb.notes = [] }; tb.notes?.append(newNote) }
            count += 1
        }
        try? modelContext.save()
        var log = AttributedString("✅ 导入成功！共入库 "); var countStr = AttributedString("\(count)"); countStr.foregroundColor = .purple
        log.append(countStr); log.append(AttributedString(" 条笔记。"))
        showRichFeedback(log); pendingNotes.removeAll()
    }
    
    private func generateManualRecords() {
        guard let targetBook = allBooks.first(where: { $0.id == selectedBookIDForRecord }) else { return }
        let calendar = Calendar.current
        guard let start = calendar.startOfDay(for: recordStartDate) as Date?, let end = calendar.startOfDay(for: recordEndDate) as Date? else { return }
        
        var currentDate = start; var addedCount = 0
        while currentDate <= end {
            // ✨ 修复：从 reading_record 改为了 readingRecords
            let existingRecords = targetBook.readingRecords ?? []
            let exists = existingRecords.contains { record in calendar.isDate(record.date ?? Date(), inSameDayAs: currentDate) }
            if !exists {
                let newRecord = ReadingRecord(date: currentDate, book: targetBook); newRecord.readingDuration = 1800
                modelContext.insert(newRecord)
                if targetBook.readingRecords == nil { targetBook.readingRecords = [] }
                targetBook.readingRecords?.append(newRecord)
                addedCount += 1
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDay
        }
        targetBook.startTime = start; targetBook.endTime = end; targetBook.status = .finished; targetBook.progress = 100 // ✨ 修复：status 改为枚举
        try? modelContext.save()
        var log = AttributedString("✨ 轨迹生成完毕！为《\(targetBook.title ?? "")》添加了 ")
        var countStr = AttributedString("\(addedCount)"); countStr.foregroundColor = .mint
        log.append(countStr); log.append(AttributedString(" 天记录。"))
        showRichFeedback(log); selectedBookIDForRecord = ""
    }
    
    private func showPlainFeedback(_ msg: String) { showRichFeedback(AttributedString(msg)) }
    private func showRichFeedback(_ msg: AttributedString) {
        withAnimation { self.systemMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { withAnimation { self.systemMessage = nil } }
    }
}
#endif
