#if os(iOS)
import SwiftData
import SwiftUI

// ============================================================================
// MARK: - 🌊 2. 灵感画廊 (核心视图)
// ============================================================================

struct MobileInspirationWallView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    @Query var allExcerpts: [Excerpt]
    
    // 🖥️ 显示数据容器
    @State private var displayExcerpts: [ExcerptListItem] = []

    private var annotationFingerprint: String {
        allExcerpts
            .map { "\($0.id)|\($0.type.rawValue)|\($0.createdAt.timeIntervalSince1970)|\($0.content.hashValue)|\($0.book?.id ?? "")" }
            .joined(separator: ";")
    }
    
    var body: some View {
        let totalExcerptCharacters = displayExcerpts.reduce(0) { $0 + $1.content.count }
        let uniqueBooksCount = Set(displayExcerpts.map { $0.bookTitle }).count
        
        NavigationStack {
            ZStack(alignment: .top) {
                AppColors.primaryBackground(for: colorScheme).ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        MobileInspirationStatsHeader(
                            totalExcerpts: displayExcerpts.count,
                            totalExcerptCharacters: totalExcerptCharacters,
                            uniqueBooksCount: uniqueBooksCount
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        
                        if displayExcerpts.isEmpty {
                            emptyStateView
                        } else {
                            roamListView
                        }
                    }
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("灵感碎片")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: annotationFingerprint) { _, _ in refreshData(animate: true) }
            .onAppear { refreshData(animate: false) }
        }
    }
    
    // MARK: - 📚 布局：书籍分类模式 (✨ 顶部对齐优化的 Header)
        private var groupedCatalogView: some View {
            let grouped = Dictionary(grouping: displayExcerpts, by: { $0.bookTitle })
            let sortedKeys = grouped.keys.sorted()
            
            return LazyVStack(spacing: 32) {
                ForEach(sortedKeys, id: \.self) { bookTitle in
                    let excerpts = grouped[bookTitle]!
                    let firstExcerpt = excerpts.first
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // 外层 HStack 保持 .center，让最右侧的“数量胶囊”整体居中
                        HStack(alignment: .center) {
                            
                            // 左侧：封面 + 书名 + 作者
                            // ✨ 核心修改 1：将这里的 HStack 对齐方式改为 .top
                            HStack(alignment: .top, spacing: 12) {
                                if let coverData = firstExcerpt?.coverData {
                                    BookCoverView(coverID: firstExcerpt?.bookID ?? "", coverData: coverData, fallbackTitle: bookTitle)
                                        .frame(width: 40, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                                } else {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.secondary.opacity(0.1))
                                        .frame(width: 40, height: 60)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bookTitle)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                    
                                    Text(firstExcerpt?.bookAuthor ?? "佚名")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                // ✨ 核心修改 2：视觉补偿，让文字的最高点（Cap Height）和封面顶部完美水平
                                .padding(.top, 2)
                            }
                            
                            Spacer()
                            
                            // 右侧：碎片数量
                            Text("\(excerpts.count) 条灵感")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 20)
                        
                        // 下方：碎片卡片列表
                        LazyVStack(spacing: 16) {
                            ForEach(excerpts) { excerpt in
                                MobileUnifiedExcerptCardView(
                                    excerpt: excerpt,
                                    isMasonry: false,
                                    onDelete: { deleteExcerpt(excerpt.id) }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    
    // MARK: - 🌊 布局：原生的单列漫游列表 (✨ 移除复杂横屏，回归纯粹竖屏体验)
    private var roamListView: some View {
        LazyVStack(spacing: 16) {
            ForEach(displayExcerpts) { excerpt in
                MobileUnifiedExcerptCardView(
                    excerpt: excerpt,
                    isMasonry: true,
                    onDelete: { deleteExcerpt(excerpt.id) }
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - ⚙️ 核心数据引擎
    
    private func refreshData(animate: Bool) {
        let results = ReadingStatsCalculator.inspirationSnapshot(
            excerpts: allExcerpts,
            type: nil,
            searchText: "",
            sortKey: .newest,
            randomize: true
        ).excerpts
        
        if animate {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { self.displayExcerpts = results }
        } else {
            self.displayExcerpts = results
        }
    }
    
    // MARK: - 内部组件与逻辑
    
    private var emptyStateView: some View {
        EmptyStateView(
            systemImage: "leaf",
            title: "空空如也",
            message: "多读书，多记录，这里会长出智慧的森林。",
            minHeight: 320
        )
        .padding(.top, 24)
    }
    
    private func deleteExcerpt(_ id: String) {
        if let target = allExcerpts.first(where: { $0.id == id }) {
            try? ReadingDataService.shared.deleteExcerpt(target, context: modelContext)
        }
    }
}

// ============================================================================
// MARK: - ✨ 4. 辅助卡片组件
// ============================================================================

struct MobileInspirationStatsHeader: View {
    let totalExcerpts: Int
    let totalExcerptCharacters: Int
    let uniqueBooksCount: Int
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let formattedKCount = String(format: "%.1f", Double(totalExcerptCharacters) / 1000.0)
        
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(totalExcerptCharacters > 1000 ? formattedKCount : "\(totalExcerptCharacters)").font(.system(size: 28, weight: .heavy, design: .serif)).foregroundColor(.primary)
                    if totalExcerptCharacters > 1000 { Text("k").font(.system(size: 14, weight: .bold)).foregroundColor(.indigo) }
                }
                Text("字沉淀").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
                                                
            Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 32)
                                                
            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(uniqueBooksCount)").font(.system(size: 28, weight: .heavy, design: .serif)).foregroundColor(.primary)
                    Text("本").font(.system(size: 14, weight: .bold)).foregroundColor(.orange)
                }
                Text("知识源泉").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(AppSpacing.l)
        .background(AppColors.secondaryBackground(for: colorScheme).opacity(0.8).background(AppMaterials.card))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }
}

struct MobileUnifiedExcerptCardView: View {
    let excerpt: ExcerptListItem
    let isMasonry: Bool
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: excerpt.isNote ? "quote.opening" : "text.quote")
                    .font(.system(size: isMasonry ? 20 : 16))
                    .foregroundColor((excerpt.isNote ? Color.orange : Color.indigo).opacity(0.8))
                
                Spacer()
                
                if !isMasonry {
                    Text(excerpt.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.trailing, 4)
                }
                
                Text(excerpt.isNote ? "思考" : "摘录")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(excerpt.isNote ? .orange : .indigo)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((excerpt.isNote ? Color.orange : Color.indigo).opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Text(LocalizedStringKey(excerpt.content))
                .font(.system(size: 15, weight: .medium, design: .serif))
                .lineSpacing(6)
                .foregroundColor(.primary.opacity(0.9))
                .lineLimit(isMasonry ? 12 : nil)
            
            if isMasonry {
                Divider().opacity(0.5).padding(.vertical, 2)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("《\(excerpt.bookTitle)》")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary).lineLimit(1)
                        Text(excerpt.date.formatted(date: .numeric, time: .omitted))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    ellipsisMenu()
                }
            } else {
                HStack {
                    Spacer()
                    ellipsisMenu()
                }
            }
        }
        .padding(AppSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColors.secondaryBackground(for: colorScheme)
                .opacity(0.8)
                .background(AppMaterials.card)
        )
        .clipShape(RoundedRectangle(cornerRadius: isMasonry ? AppRadius.card : AppRadius.m, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: isMasonry ? AppRadius.card : AppRadius.m).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 3)
        .contextMenu {
            Button {
                UIPasteboard.general.string = "\"\(excerpt.content)\"\n—— 《\(excerpt.bookTitle)》"
            } label: { Label("一键拷贝", systemImage: "doc.on.doc") }
            Button(role: .destructive) { onDelete() } label: { Label("删除片段", systemImage: "trash") }
        }
    }
    
    private func ellipsisMenu() -> some View {
        Menu {
            Button {
                UIPasteboard.general.string = "\"\(excerpt.content)\"\n—— 《\(excerpt.bookTitle)》"
            } label: { Label("一键拷贝", systemImage: "doc.on.doc") }
            
            Button(role: .destructive) {
                onDelete()
            } label: { Label("删除片段", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)
                .background(AppColors.secondaryBackground(for: colorScheme).opacity(0.8), in: Circle())
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
    }
}

#endif
