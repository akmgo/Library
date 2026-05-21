#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - 🧩 右侧超紧凑组件：想读标记按钮

struct MobilePlannedStatusToggle: View {
    @Bindable var book: Book
    @Binding var showMaxAlert: Bool
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Button {
            handleToggle()
        } label: {
            // ✨ 修复：彻底弃用布尔值，改用原生状态枚举判定
            let isPlanned = book.status == .planned
            Image(systemName: isPlanned ? "bookmark.fill" : "bookmark")
                .font(.system(size: 16))
                .foregroundColor(isPlanned ? .orange : Color.gray.opacity(0.5))
                .padding(4)
        }
        .buttonStyle(.plain)
    }
    
    private func handleToggle() {
        if book.status == .planned {
            withAnimation(.spring()) {
                try? ReadingDataService.shared.updateStatus(book, to: .unread, context: modelContext)
            }
        } else {
            do {
                // ✨ 安全过滤：在内存中过滤以防 #Predicate 引起 SQLite 崩溃
                let allBooks = try modelContext.fetch(FetchDescriptor<Book>())
                let count = allBooks.filter { $0.status == .planned }.count
                
                if count >= 4 {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    showMaxAlert = true
                } else {
                    withAnimation(.spring()) {
                        try? ReadingDataService.shared.updateStatus(book, to: .planned, context: modelContext)
                    }
                }
            } catch { print("想读状态查询失败: \(error)") }
        }
    }
}

// MARK: - 🧩 右侧超紧凑组件：状态选择器

struct MobileCompactStatusPicker: View {
    @Bindable var book: Book
    var animationNamespace: Namespace.ID
    @Environment(\.modelContext) private var modelContext
    
    // “想读”不放在选择器里，靠书签按钮触发，所以这里只放核心三态
    let options: [(BookStatus, String)] = [(.unread, "待读"), (.reading, "在读"), (.finished, "已读完")]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { opt in
                let isSelected = book.status == opt.0
                Button(action: {
                    handleStatusChange(to: opt.0)
                }) {
                    ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(AppColors.selection)
                                .matchedGeometryEffect(id: "mobile-status-bg", in: animationNamespace)
                        }
                        Text(opt.1)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .white : .secondary)
                    }
                    .frame(height: 24)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private func handleStatusChange(to newStatus: BookStatus) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            try? ReadingDataService.shared.updateStatus(book, to: newStatus, context: modelContext)
        }
    }
}

// MARK: - 🧩 右侧超紧凑组件：双列日期与历时区块

struct MobileCompactDatePickers: View {
    @Bindable var book: Book
    var body: some View {
        HStack(spacing: 8) {
            VStack(spacing: 6) {
                CompactDateBtn(icon: "play.fill", title: "开始", date: $book.startDate)
                CompactDateBtn(icon: "flag.fill", title: "结束", date: $book.finishDate, isDisabled: book.status != .finished)
            }
            
            if book.status == .finished, let start = book.startDate, let end = book.finishDate {
                let days = max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1)
                VStack(spacing: 2) {
                    Text("\(days)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.mint)
                    Text("历时(天)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .frame(width: 56, height: 54)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

struct CompactDateBtn: View {
    let icon: String; let title: String; @Binding var date: Date?; var isDisabled: Bool = false
    @State private var showPicker = false
    
    var body: some View {
        Button(action: { showPicker = true }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(date != nil ? .blue : Color.gray.opacity(0.5))
                
                if let d = date {
                    Text(d.formatted(date: .numeric, time: .omitted))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                } else {
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1.0)
        .popover(isPresented: $showPicker) {
            DatePicker("", selection: Binding(get: { date ?? Date() }, set: { date = $0 }), displayedComponents: .date)
                .datePickerStyle(.graphical).padding()
        }
    }
}

// MARK: - 🧩 右侧超紧凑组件：小星级与评价文字

struct MobileCompactRatingView: View {
    @Bindable var book: Book
    let ratingTexts = ["", "一星毒草", "二星平庸", "三星粮草", "四星推荐", "改变人生"]
    
    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(1 ... 5, id: \.self) { star in
                    let isFilled = book.rating >= star
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(isFilled ? .yellow : Color.secondary.opacity(0.2))
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3)) { book.rating = star }
                        }
                }
            }
            Spacer()
            if book.rating > 0 {
                Text(book.rating < ratingTexts.count ? ratingTexts[book.rating] : "")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
                if book.rating == 5 { Image(systemName: "crown.fill").font(.system(size: 10)).foregroundColor(.orange) }
            } else {
                Text("暂无评价").font(.system(size: 10, weight: .medium)).foregroundColor(Color.gray.opacity(0.5))
            }
        }
    }
}

// MARK: - 🧩 底部超紧凑组件：自适应多行标签网格

struct MobileCompactTagsView: View {
    @Bindable var book: Book
    let predefinedTags = ["哲学", "历史", "商业", "科技", "文学", "成长", "设计", "心理", "传记", "管理"]
    
    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 54, maximum: 70), spacing: 8)]
        
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(predefinedTags, id: \.self) { tag in
                let isSelected = book.tags.contains(tag)
                let isMaxed = book.tags.count >= 3 && !isSelected
                
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        // ✨ 修复：非可选数组的丝滑操作
                        if isSelected {
                            book.tags.removeAll(where: { $0 == tag })
                        } else if book.tags.count < 3 {
                            book.tags.append(tag)
                        }
                    }
                }) {
                    Text(tag)
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(isSelected ? Color.indigo : Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .disabled(isMaxed)
                .opacity(isMaxed ? 0.4 : 1.0)
            }
        }
    }
}
#endif
