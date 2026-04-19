#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 📑 手动打卡弹窗
struct MobileManualLogSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var defaultBook: Book
    var allBooks: [Book]
    
    @State private var selectedBook: Book
    @State private var logDate: Date = Date()
    @State private var logMinutes: Int = 30
    
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
                    
                    // ✨ 加入 .environment，强制让日历组件使用中文语言环境 (显示几月几日)
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
    
    private func saveLog() {
        let cal = Calendar.current
        let targetDate = cal.startOfDay(for: logDate)
        
        let existingRecord = selectedBook.readingRecords?.first { record in
            guard let rDate = record.date else { return false }
            return cal.isDate(rDate, inSameDayAs: targetDate)
        }
        
        let secondsToAdd = TimeInterval(logMinutes * 60)
        
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
