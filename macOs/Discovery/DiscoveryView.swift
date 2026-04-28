#if os(macOS)
import SwiftUI
import SwiftData
import ImageIO

// MARK: - 🌌 云海拾贝 · 私人发现画廊

struct DiscoveryView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var engine = DiscoveryEngine.shared
    
    @State private var isEntranceAnimated: Bool = false
    
    private let quotes = [
        ("「阅读是一座随身携带的避难所」", "威廉·萨默塞特·毛姆"),
        ("「书籍是屹立在时间的汪洋大海中的灯塔」", "惠普尔"),
        ("「脚步不能到达的地方，眼光可以到达」", "维克多·雨果"),
        ("「读一本好书，就是和许多高尚的人谈话」", "笛卡尔"),
        ("「吾生也有涯，而知也无涯」", "《庄子》")
    ]
    @State private var dailyQuote: (text: String, author: String) = ("", "")
    
    var body: some View {
        ZStack {
            // 1. ⬇️ 底层 content 滚动区
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 140)
                    
                    HStack(alignment: .top, spacing: 0) {
                        let categories = DiscoveryCategory.allCases
                        ForEach(Array(categories.enumerated()), id: \.element) { index, category in
                            DiscoveryColumn(category: category, engine: engine)
                                .frame(maxWidth: .infinity, alignment: .top)
                                .padding(.horizontal, 24)
                            
                            if index < categories.count - 1 {
                                Divider()
                                    .opacity(0.5)
                                    .padding(.top, 60)
                                    .padding(.bottom, 20)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer(minLength: 80)
                }
                // 升空动效
                .opacity(isEntranceAnimated ? 1.0 : 0.0)
                .offset(y: isEntranceAnimated ? 0 : 150)
                .scaleEffect(isEntranceAnimated ? 1.0 : 0.99, anchor: .center)
                .animation(.appFluidSpring, value: isEntranceAnimated)
            }
        }
        // 2. ✨ 顶层悬浮 Header
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("云海拾贝")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.top, 8)
                        Text("Explore what the world is reading...")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .opacity(isEntranceAnimated ? 1.0 : 0.0)
                    .offset(x: isEntranceAnimated ? 0 : -150)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(dailyQuote.text)
                            .font(.system(size: 15, weight: .medium, design: .serif))
                            .italic()
                            .foregroundColor(.primary.opacity(0.85))
                        Text("— \(dailyQuote.author)")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .opacity(isEntranceAnimated ? 1.0 : 0.0)
                    .offset(x: isEntranceAnimated ? 0 : 150)
                }
                .padding(.horizontal, 40)
                .padding(.top, 45)
                .padding(.bottom, 20)
                .animation(.spring(response: 0.8, dampingFraction: 0.75), value: isEntranceAnimated)
                
                Divider().background(Color.primary.opacity(0.05))
            }
            .frame(height: 130, alignment: .bottom)
            .background(Color.clear.background(.ultraThinMaterial).opacity(0.85))
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            if dailyQuote.text.isEmpty { dailyQuote = quotes.randomElement()! }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isEntranceAnimated = true }
        }
        .task {
            await engine.loadAllCategories(context: modelContext)
        }
    }
}

// MARK: - 🏛️ 单个列展示区

private struct DiscoveryColumn: View {
    let category: DiscoveryCategory
    @ObservedObject var engine: DiscoveryEngine
    
    var body: some View {
        VStack(spacing: 0) {
            // ✨ 左对齐、放大且无背板的标题
            HStack(spacing: 8) {
                Text(category.rawValue)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(category.themeColor)
                
                if engine.isFetching[category] == true {
                    ProgressView().controlSize(.small)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 24)
            
            VStack(spacing: 20) {
                if let books = engine.visibleBooks[category], !books.isEmpty {
                    ForEach(books) { book in
                        DiscoveryHorizontalCard(book: book, category: category, engine: engine)
                    }
                } else if engine.isFetching[category] != true {
                    Text("暂无更多推荐。")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 40)
                }
            }
        }
    }
}

// MARK: - 🃏 横向流体图书卡片 (极简UI版)

private struct DiscoveryHorizontalCard: View {
    let book: BookSearchResult
    let category: DiscoveryCategory
    @ObservedObject var engine: DiscoveryEngine
    @Environment(\.modelContext) private var modelContext
    
    @State private var isHovered = false
    @State private var rawCoverData: Data?
    @State private var decodedImage: NSImage?
    @State private var isLoadingCover: Bool
    
    init(book: BookSearchResult, category: DiscoveryCategory, engine: DiscoveryEngine) {
        self.book = book
        self.category = category
        self.engine = engine
        
        if let url = book.coverURL, let cachedImg = DiscoveryCoverCache.shared.object(forKey: url as NSString) {
            _decodedImage = State(initialValue: cachedImg)
            _isLoadingCover = State(initialValue: false)
        } else {
            _decodedImage = State(initialValue: nil)
            _isLoadingCover = State(initialValue: true)
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                if let img = decodedImage {
                    Image(nsImage: img).resizable().scaledToFill()
                } else {
                    Rectangle().fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    if isLoadingCover { ProgressView().controlSize(.mini) }
                }
            }
            .frame(width: 72, height: 108)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            .task(id: book.coverURL) {
                if decodedImage != nil { return }
                guard let url = book.coverURL else { return }
                
                if let data = await CloudSearchManager.shared.fetchCoverData(from: url) {
                    let img = await Task.detached(priority: .userInitiated) { () -> NSImage? in
                        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 300] as CFDictionary
                        if let source = CGImageSourceCreateWithData(data as CFData, nil), let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) {
                            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                        }
                        return NSImage(data: data)
                    }.value
                    
                    await MainActor.run {
                        self.rawCoverData = data
                        self.decodedImage = img
                        self.isLoadingCover = false
                        if let validImg = img { DiscoveryCoverCache.shared.setObject(validImg, forKey: url as NSString) }
                    }
                } else { isLoadingCover = false }
            }
            
            // ✨ 极简卡片信息区：去除描述，自然贴合，底部按钮锁定对齐
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isHovered ? category.themeColor : .primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true) // 自然撑开，无多余空隙
                
                Text(book.author)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer(minLength: 0) // 将按钮区死死推到底部
                
                HStack(spacing: 8) {
                    Button(action: importToLibrary) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("待读")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(category.themeColor.opacity(isHovered ? 0.9 : 0.15))
                        .foregroundColor(isHovered ? .white : category.themeColor)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { engine.dismissBook(book, in: category) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 26, height: 26)
                            .background(Color.primary.opacity(isHovered ? 0.1 : 0.05))
                            .foregroundColor(.secondary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("屏蔽此书")
                }
            }
            .frame(height: 108) // 锁定整个右侧信息区高度与封面一模一样
            .padding(.vertical, 0)
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(height: 132) // 锁定整张卡片总高 (108 + 12*2)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(isHovered ? 0.85 : 0.5))
                .shadow(color: .black.opacity(isHovered ? 0.08 : 0.02), radius: isHovered ? 8 : 2, y: isHovered ? 4 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isHovered ? category.themeColor.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.appSnappy, value: isHovered)
        .onHover { h in
            isHovered = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
    
    private func importToLibrary() {
        Task { @MainActor in
            let newBook = Book(title: book.title, author: book.author)
            newBook.coverData = self.rawCoverData
            newBook.status = .wantToRead
            modelContext.insert(newBook)
            try? modelContext.save()
            NotificationCenter.default.post(name: .libraryDidUpdate, object: nil)
            engine.consumeAndReplenish(bookID: book.id, in: category)
        }
    }
}
#endif
