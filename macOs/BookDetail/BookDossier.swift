#if os(macOS)
import SwiftUI
import SwiftData

// MARK: - ✨ 书籍核心信息档案板

/// 详情页上半部分的核心信息交互展板。
///
/// **职责与特性：**
/// 使用 `@Bindable` 直接绑定传入的 `Book` 实例，用户在 UI 上点击星标、切换状态、勾选标签时，
/// 数据会无缝且即时地同步到 SwiftData 底层，无需手动触发 Save。
struct BookDossierView: View {
    @Bindable var book: Book
    @Namespace private var animationNamespace
    @State private var showMaxWantToReadAlert = false
    
    var body: some View {
        let safeTitle = book.title ?? "未知书名"
        let safeAuthor = book.author ?? "未知作者"
        
        VStack(alignment: .leading, spacing: 32) {
            // ================= 👆 上半部分：左右分栏 =================
            HStack(alignment: .top, spacing: 40) {
                
                // 👈 左侧：高清大封面
                LocalCoverView(coverData: book.coverData, fallbackTitle: safeTitle)
                    .frame(width: 300, height: 450)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                
                // 👉 右侧：书名与交互台
                VStack(alignment: .leading, spacing: 0) {
                    
                    // 1. 书名与作者
                    HStack(alignment: .top) {
                        HStack(alignment: .center, spacing: 16) {
                            Text(safeTitle)
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            if book.status == .unread {
                                WantToReadToggle(book: book, showMaxAlert: $showMaxWantToReadAlert)
                                    .offset(y: -4)
                            }
                        }
                        
                        Spacer(minLength: 20)
                        
                        Text(safeAuthor)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(2)
                            .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    // 2. 依次垂直紧凑堆叠组件
                    VStack(alignment: .leading, spacing: 20) {
                        BookStatusPicker(book: book, animationNamespace: animationNamespace)
                        BookDatePickers(book: book)
                        BookRatingView(book: book)
                    }
                }
                .frame(height: 450)
                .frame(maxWidth: .infinity)
            }
            
            // ================= 👇 下半部分：标签模块 =================
            BookTagsView(book: book)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
        .alert("席位已满", isPresented: $showMaxWantToReadAlert) {
            Button("知道啦", role: .cancel) {}
        } message: {
            Text("你的主页“想读焦点”最多只能同时放置 2 本书。请先取消其他的想读状态，把位置腾出来吧！")
        }
    }
}

// MARK: - 子组件：状态选择器
private struct BookStatusPicker: View {
    @Bindable var book: Book
    var animationNamespace: Namespace.ID
    
    @Environment(\.modelContext) private var modelContext
    let statusOptions: [(BookStatus, String)] = [(.unread, "待读"), (.reading, "在读"), (.finished, "已读")]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("当前状态", systemImage: "book.fill").font(.system(size: 15, weight: .bold)).foregroundColor(.blue)
            
            HStack(spacing: 0) {
                ForEach(statusOptions, id: \.0) { opt in
                    let isSelected = (book.status ?? .unread) == opt.0
                    Button(action: { handleStatusChange(to: opt.0) }) {
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.blue).matchedGeometryEffect(id: "status-bg", in: animationNamespace)
                            }
                            Text(opt.1).font(.system(size: 14, weight: isSelected ? .bold : .medium)).foregroundColor(isSelected ? .white : .primary).frame(maxWidth: .infinity, maxHeight: .infinity)
                        }.frame(height: 36)
                    }
                    .buttonStyle(.plain).onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                }
            }
            .padding(4).background(Color(nsColor: .controlBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
        }
    }
    
    /// 执行状态切换，并智能级联更新时间戳。
    private func handleStatusChange(to newStatus: BookStatus) {
        let oldStatus = book.status ?? .unread
        let wasFinished = (oldStatus == .finished)
        let willFinish = (newStatus == .finished)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            book.status = newStatus
            let now = Date()
            if newStatus == .reading {
                if book.startTime == nil { book.startTime = now }
            } else if newStatus == .finished {
                if book.startTime == nil { book.startTime = now }
                if book.endTime == nil { book.endTime = now }
            }
        }
        
        if willFinish && !wasFinished {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { NotificationCenter.default.post(name: .triggerConfetti, object: nil) }
        }
    }
}

// MARK: - 子组件：个人评分
private struct BookRatingView: View {
    @Bindable var book: Book
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("个人评分", systemImage: "star.fill").font(.system(size: 15, weight: .bold)).foregroundColor(.yellow)
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { index in
                    let currentRating = book.rating ?? 0
                    Image(systemName: currentRating >= index ? "star.fill" : "star")
                        .font(.system(size: 24)).foregroundColor(currentRating >= index ? .yellow : .secondary.opacity(0.3))
                        .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { book.rating = currentRating == index ? 0 : index } }
                        .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .center).background(Color(nsColor: .windowBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
        }
    }
}

// MARK: - 子组件：标签库
private struct BookTagsView: View {
    @Bindable var book: Book
    let predefinedTags: [String] = ["哲学", "历史", "人文", "经典", "社会", "政治", "经济", "法律", "心理", "思考", "成长", "管理", "商业", "投资", "技术", "文学", "传记", "艺术", "宗教", "科普", "编程", "玄幻"]
    
    var body: some View {
        let safeTags: [String] = book.tags ?? []
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("知识标签库", systemImage: "tag.fill").font(.system(size: 15, weight: .bold)).foregroundColor(.purple)
                Spacer()
                Text("\(safeTags.count) / 3").font(.system(size: 14, weight: .bold)).foregroundColor(.secondary)
            }
            let columns = [GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 12)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(predefinedTags, id: \.self) { tag in
                    let isSelected = safeTags.contains(tag)
                    let isMaxed = safeTags.count >= 3 && !isSelected
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            var currentTags = book.tags ?? []
                            if isSelected { currentTags.removeAll(where: { $0 == tag }) }
                            else if currentTags.count < 3 { currentTags.append(tag) }
                            book.tags = currentTags
                        }
                    }) {
                        Text(tag).font(.system(size: 14, weight: isSelected ? .bold : .medium)).foregroundColor(isSelected ? .white : (isMaxed ? .secondary.opacity(0.6) : .primary)).frame(height: 36).frame(maxWidth: .infinity).background(isSelected ? Color.purple : (isMaxed ? Color.secondary.opacity(0.05) : Color(nsColor: .controlBackgroundColor))).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isSelected ? Color.purple : Color.secondary.opacity(0.1), lineWidth: 1)).scaleEffect(isSelected ? 1.05 : 1.0)
                    }
                    .buttonStyle(.plain).disabled(isMaxed).onHover { h in if h && !isMaxed { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                }
            }
        }
    }
}

// MARK: - 子组件：想读焦点开关
struct WantToReadToggle: View {
    @Bindable var book: Book
    @Binding var showMaxAlert: Bool
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Button(action: handleToggle) {
            Image(systemName: book.isWantToRead ? "bookmark.fill" : "bookmark").font(.system(size: 16, weight: .bold)).foregroundColor(book.isWantToRead ? .orange : .secondary).frame(width: 36, height: 36).background(book.isWantToRead ? Color.orange.opacity(0.1) : Color(nsColor: .controlBackgroundColor)).clipShape(Circle()).overlay(Circle().stroke(book.isWantToRead ? Color.orange.opacity(0.3) : Color.secondary.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain).help(book.isWantToRead ? "取消想读焦点" : "加入主页想读焦点 (最多4本)")
    }
    
    private func handleToggle() {
        if book.isWantToRead {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { book.isWantToRead = false }
        } else {
            do {
                let descriptor = FetchDescriptor<Book>(predicate: #Predicate<Book> { $0.isWantToRead == true })
                let currentCount = try modelContext.fetchCount(descriptor)
                if currentCount >= 4 { NSSound.beep(); showMaxAlert = true } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { book.isWantToRead = true }
                }
            } catch { print("查询失败: \(error)") }
        }
    }
}
#endif
