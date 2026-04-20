import SwiftUI
import SwiftData

#if os(iOS)
// MARK: - 📑 手动打卡与轨迹生成表单

/// 处理用户手动补录单次阅读记录的业务视图。
///
/// **场景与逻辑：**
/// 常用于用户忘记开启专注番茄钟，或者单纯想补录昨天的阅读时间。
/// 它会要求选择“目标书籍”、“日期”和“专注时长”。
/// 提交时，如果该书在指定日期已有记录，则智能执行**累加合并**操作，否则新建独立的流水记录。
struct MobileManualLogSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var defaultBook: Book
    var allBooks: [Book]
    
    @State private var selectedBook: Book
    @State private var logDate: Date = Date()
    @State private var logMinutes: Int = 30
    
    /// 自动筛选出处于在读状态的书籍供用户快速挑选
    var readingBooks: [Book] {
        allBooks.filter { $0.status == .reading }
    }
    
    init(defaultBook: Book, allBooks: [Book]) {
        self.defaultBook = defaultBook
        self.allBooks = allBooks
        _selectedBook = State(initialValue: defaultBook)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("书籍与时间")) {
                    Picker("选择书籍", selection: $selectedBook) {
                        ForEach(readingBooks) { book in
                            Text(book.title ?? "未知书籍").tag(book)
                        }
                    }
                    
                    // ✨ 加入 .environment，强制让日历组件使用中文语言环境 (完美显示几月几日)
                    DatePicker("打卡日期", selection: $logDate, in: ...Date(), displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                }
                
                Section(header: Text("阅读时长 (分钟)")) {
                    Stepper(value: $logMinutes, in: 1...600, step: 5) {
                        HStack {
                            Text("\(logMinutes)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.indigo)
                            Text("分钟")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button(action: saveLog) {
                        HStack {
                            Spacer()
                            Text("确认打卡")
                                .font(.system(size: 16, weight: .bold))
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    // 使用极其突出的原生系统渐变色增强可点击感
                    .listRowBackground(Rectangle().fill(Color.indigo.gradient))
                }
            }
            .navigationTitle("补录阅读记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - 合并与持久化引擎
    
    private func saveLog() {
        let cal = Calendar.current
        let targetDate = cal.startOfDay(for: logDate)
        
        // 查找同一天是否已有流水记录
        let existingRecord = selectedBook.readingRecords?.first { record in
            guard let rDate = record.date else { return false }
            return cal.isDate(rDate, inSameDayAs: targetDate)
        }
        
        let secondsToAdd = TimeInterval(logMinutes * 60)
        
        // 如果存在则累加，不存在则开新行
        if let record = existingRecord {
            record.readingDuration += secondsToAdd
        } else {
            let newRecord = ReadingRecord(date: logDate, readingDuration: secondsToAdd, book: selectedBook)
            modelContext.insert(newRecord)
            if selectedBook.readingRecords == nil { selectedBook.readingRecords = [] }
            selectedBook.readingRecords?.append(newRecord)
        }
        
        try? modelContext.save()
        dismiss()
    }
}
#endif
