#if os(macOS)
import SwiftUI
import SwiftData

// MARK: - ✨ UI 视图模块扩展

/// 将庞大的 `Form` 按照业务区块拆分为细粒度的 `@ViewBuilder` 组件。
extension DataPanelSettingsView {
    
    // ================= 1. 数据导入区块 =================
    @ViewBuilder
    internal var importSection: some View {
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
                    Button(action: executeBookImport) { Text("开始导入").bold().padding(.horizontal, 12).padding(.vertical, 4) }
                    .buttonStyle(.borderedProminent).tint(.blue).disabled(pendingBooks.isEmpty)
                }.padding(.leading, 44)
            }.padding(.vertical, 8)
            
            // 摘录导入
            VStack(alignment: .leading, spacing: 12) {
                SettingsHeaderRow(icon: "quote.opening", iconColor: .orange, title: "摘录导入", subtitle: "从外部文件导入您的灵感摘录")
                HStack {
                    Button(action: { activeImportType = .excerpt; showExcerptPicker = true }) { Text(pendingExcerpts.isEmpty ? "选择摘录" : "已选 \(pendingExcerpts.count) 条摘录").frame(width: 140) }
                    Spacer()
                    Button(action: executeExcerptImport) { Text("开始导入").bold().padding(.horizontal, 12).padding(.vertical, 4) }
                    .buttonStyle(.borderedProminent).tint(.orange).disabled(pendingExcerpts.isEmpty)
                }.padding(.leading, 44)
            }.padding(.vertical, 8)
            
            // 笔记导入
            VStack(alignment: .leading, spacing: 12) {
                SettingsHeaderRow(icon: "highlighter", iconColor: .purple, title: "笔记导入", subtitle: "批量导入您的结构化读书笔记")
                HStack {
                    Button(action: { activeImportType = .note; showNotePicker = true }) { Text(pendingNotes.isEmpty ? "选择笔记" : "已选 \(pendingNotes.count) 条笔记").frame(width: 140) }
                    Spacer()
                    Button(action: executeNoteImport) { Text("开始导入").bold().padding(.horizontal, 12).padding(.vertical, 4) }
                    .buttonStyle(.borderedProminent).tint(.purple).disabled(pendingNotes.isEmpty)
                }.padding(.leading, 44)
            }.padding(.vertical, 8)
            
            // 外部轨迹导入
            VStack(alignment: .leading, spacing: 12) {
                SettingsHeaderRow(icon: "clock.arrow.circlepath", iconColor: .cyan, title: "外部轨迹导入", subtitle: "批量导入并智能匹配指定书籍的历史阅读记录 (JSON)")
                HStack {
                    Button(action: { activeImportType = .record; showRecordPicker = true }) { Text(pendingRecords.isEmpty ? "选择历史轨迹" : "已选 \(pendingRecords.count) 天记录").frame(width: 140) }
                    Spacer()
                    Button(action: executeRecordImport) { Text("开始导入").bold().padding(.horizontal, 12).padding(.vertical, 4) }
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
                        .labelsHidden().pickerStyle(.menu).frame(width: 150).padding(.horizontal, 8).padding(.vertical, 6).background(Color(nsColor: .controlBackgroundColor)).cornerRadius(6)
                    }
                    Divider().opacity(0.5)
                    HStack {
                        Text("开始日期").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary)
                        Spacer()
                        DatePicker("", selection: $recordStartDate, displayedComponents: .date).labelsHidden().datePickerStyle(.stepperField).frame(width: 150).padding(.horizontal, 8).padding(.vertical, 6).background(Color(nsColor: .controlBackgroundColor)).cornerRadius(6)
                    }
                    Divider().opacity(0.5)
                    HStack {
                        Text("结束日期").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary)
                        Spacer()
                        DatePicker("", selection: $recordEndDate, displayedComponents: .date).labelsHidden().datePickerStyle(.stepperField).frame(width: 150).padding(.horizontal, 8).padding(.vertical, 6).background(Color(nsColor: .controlBackgroundColor)).cornerRadius(6)
                    }
                    Button(action: generateManualRecords) {
                        HStack { Spacer(); Image(systemName: "sparkles"); Text("开始生成阅读记录"); Spacer() }
                        .font(.system(size: 13, weight: .bold)).padding(.vertical, 8)
                        .background(selectedBookIDForRecord.isEmpty || recordStartDate > recordEndDate ? Color.gray : Color.mint).cornerRadius(8)
                    }
                    .buttonStyle(.plain).disabled(selectedBookIDForRecord.isEmpty || recordStartDate > recordEndDate).padding(.top, 4)
                }.padding(.leading, 44)
            }.padding(.vertical, 8)
            
        } header: { Text("数据导入").font(.system(size: 16, weight: .bold)).padding(.bottom, 6) }
        .padding(.bottom, 16)
    }
    
    // ================= 2. 数据导出区块 =================
    @ViewBuilder
    internal var exportSection: some View {
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
    }
    
    // ================= 3. 数据同步区块 =================
    @ViewBuilder
    internal var syncSection: some View {
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
    }
    
    // ================= 4. 危险操作区 =================
    @ViewBuilder
    internal var dangerSection: some View {
        Section {
            HStack(spacing: 16) {
                SettingsHeaderRow(icon: "trash.slash.fill", iconColor: .gray, title: "删除指定数据", subtitle: "选择性清理多余的书籍、笔记或失效的阅读记录")
                Spacer()
                Button("选择清理") { booksToDelete.removeAll(); showingDeleteSelectionSheet = true }
            }.padding(.vertical, 8)
            
            HStack(spacing: 16) {
                SettingsHeaderRow(icon: "exclamationmark.triangle.fill", iconColor: .red, title: "抹除全部数据", subtitle: "警告：此操作将清空库中所有内容，且不可恢复")
                Spacer()
                Button(role: .destructive, action: { showingDeleteAlert = true }) { Text("抹除数据").foregroundColor(.red) }
            }.padding(.vertical, 8)
        } header: { Text("危险区").font(.system(size: 16, weight: .bold)).foregroundColor(.red).padding(.bottom, 6) }
    }
}
#endif
