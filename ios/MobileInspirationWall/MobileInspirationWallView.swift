#if os(iOS)
import SwiftData
import SwiftUI

// ============================================================================
// MARK: - 🎨 1. 灵感画廊枚举与 DTO 模型
// ============================================================================

enum MobileInspirationType: String, CaseIterable, Identifiable, CustomStringConvertible {
    case all = "全部内容"
    case excerpt = "精彩摘录"
    case note = "我的笔记"
    var description: String { self.rawValue }
    var id: String { self.rawValue }
}

enum MobileInspirationSort: String, CaseIterable, Identifiable, CustomStringConvertible {
    case newest = "最新添加"
    case oldest = "最早添加"
    var description: String { self.rawValue }
    var id: String { self.rawValue }
}

// ============================================================================
// MARK: - 🌊 2. 灵感画廊 (核心视图)
// ============================================================================

struct MobileInspirationWallView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    @Query var allAnnotations: [BookAnnotation]
    
    // 🔍 状态池
    @State private var contentType: MobileInspirationType = .all
    @State private var sortType: MobileInspirationSort = .newest
    @State private var isRandomRoam: Bool = true
    
    // 🗑️ 批量管理状态
    @State private var isBatchEditMode = false
    @State private var selectedSnippetsForBatch = Set<String>()
    
    // 🖥️ 显示数据容器
    @State private var displaySnippets: [InspirationSnippet] = []

    private var annotationFingerprint: String {
        allAnnotations
            .map { "\($0.id)|\($0.type.rawValue)|\($0.createdAt.timeIntervalSince1970)|\($0.content.hashValue)|\($0.book?.id ?? "")" }
            .joined(separator: ";")
    }
    
    var body: some View {
        let totalSnippetCharacters = displaySnippets.reduce(0) { $0 + $1.content.count }
        let uniqueBooksCount = Set(displaySnippets.map { $0.bookTitle }).count
        
        NavigationStack {
            ZStack(alignment: .top) {
                AppColors.primaryBackground(for: colorScheme).ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        MobileInspirationStatsHeader(
                            totalSnippets: displaySnippets.count,
                            totalSnippetCharacters: totalSnippetCharacters,
                            uniqueBooksCount: uniqueBooksCount
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        
                        if displaySnippets.isEmpty {
                            emptyStateView
                        } else {
                            if isRandomRoam {
                                roamListView
                            } else {
                                groupedCatalogView
                            }
                        }
                    }
                    .padding(.bottom, isBatchEditMode ? 140 : 80)
                }
            }
            .navigationTitle("灵感碎片")
            .navigationBarTitleDisplayMode(.large)
            
            // 底部悬浮批量操作栏
            .safeAreaInset(edge: .bottom) {
                if isBatchEditMode {
                    batchActionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onChange(of: isBatchEditMode) { _, newValue in
                if !newValue { selectedSnippetsForBatch.removeAll() }
            }
            
            // 顶部工具栏
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    MobileBatchEditToggleButton(isEditing: $isBatchEditMode)
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        // 1. 布局模式切换 (✨ 已去掉多余的洗牌按钮)
                        MobileLayoutToggleButton(isRandomRoam: $isRandomRoam)
                        
                        // 2. 状态分类筛选
                        MobileFilterMenuButton(
                            selection: $contentType,
                            options: Array(MobileInspirationType.allCases),
                            activeIcon: "line.3.horizontal.decrease.circle.fill",
                            inactiveIcon: "line.3.horizontal.decrease.circle",
                            isFiltered: contentType != .all
                        )
                        
                        // 3. 排序方式
                        MobileSortMenuButton(
                            selection: $sortType,
                            options: Array(MobileInspirationSort.allCases)
                        )
                    }
                }
            }
            .onChange(of: contentType) { _, _ in refreshData(animate: true) }
            .onChange(of: sortType) { _, _ in refreshData(animate: true) }
            .onChange(of: isRandomRoam) { _, _ in refreshData(animate: true) }
            .onChange(of: annotationFingerprint) { _, _ in refreshData(animate: true) }
            .onAppear { refreshData(animate: false) }
        }
    }
    
    // MARK: - 📚 布局：书籍分类模式 (✨ 顶部对齐优化的 Header)
        private var groupedCatalogView: some View {
            let grouped = Dictionary(grouping: displaySnippets, by: { $0.bookTitle })
            let sortedKeys = grouped.keys.sorted()
            
            return LazyVStack(spacing: 32) {
                ForEach(sortedKeys, id: \.self) { bookTitle in
                    let snippets = grouped[bookTitle]!
                    let firstSnippet = snippets.first
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // 外层 HStack 保持 .center，让最右侧的“数量胶囊”整体居中
                        HStack(alignment: .center) {
                            
                            // 左侧：封面 + 书名 + 作者
                            // ✨ 核心修改 1：将这里的 HStack 对齐方式改为 .top
                            HStack(alignment: .top, spacing: 12) {
                                if let coverData = firstSnippet?.coverData {
                                    BookCoverView(coverID: firstSnippet?.bookID ?? "", coverData: coverData, fallbackTitle: bookTitle)
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
                                    
                                    Text(firstSnippet?.bookAuthor ?? "佚名")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                // ✨ 核心修改 2：视觉补偿，让文字的最高点（Cap Height）和封面顶部完美水平
                                .padding(.top, 2)
                            }
                            
                            Spacer()
                            
                            // 右侧：碎片数量
                            Text("\(snippets.count) 条灵感")
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
                            ForEach(snippets) { snippet in
                                MobileUnifiedSnippetCardView(
                                    snippet: snippet,
                                    isMasonry: false,
                                    isBatchEditMode: isBatchEditMode,
                                    isSelected: selectedSnippetsForBatch.contains(snippet.id),
                                    onToggleSelect: { toggleSelection(for: snippet.id) },
                                    onDelete: { deleteSnippet(snippet.id) }
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
            ForEach(displaySnippets) { snippet in
                MobileUnifiedSnippetCardView(
                    snippet: snippet,
                    isMasonry: true,
                    isBatchEditMode: isBatchEditMode,
                    isSelected: selectedSnippetsForBatch.contains(snippet.id),
                    onToggleSelect: { toggleSelection(for: snippet.id) },
                    onDelete: { deleteSnippet(snippet.id) }
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - ⚙️ 核心数据引擎
    
    private func refreshData(animate: Bool) {
        let results = ReadingStatsCalculator.inspirationSnapshot(
            annotations: allAnnotations,
            type: contentType.annotationType,
            searchText: "",
            sortKey: sortType.annotationSortKey,
            randomize: isRandomRoam
        ).snippets
        
        if animate {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { self.displaySnippets = results }
        } else {
            self.displaySnippets = results
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
    
    private var batchActionBar: some View {
        HStack {
            Button(action: {
                if selectedSnippetsForBatch.count == displaySnippets.count {
                    selectedSnippetsForBatch.removeAll()
                } else {
                    selectedSnippetsForBatch = Set(displaySnippets.map { $0.id })
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                Text(selectedSnippetsForBatch.count == displaySnippets.count ? "取消全选" : "全选").font(.system(size: 16, weight: .medium))
            }
            Spacer()
            Text("已选择 \(selectedSnippetsForBatch.count) 项").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.secondary)
            Spacer()
            Button(role: .destructive, action: deleteSelectedSnippets) {
                Text("删除").font(.system(size: 16, weight: .bold))
            }
            .disabled(selectedSnippetsForBatch.isEmpty)
        }
        .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 16)
        .background(.regularMaterial)
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(.secondary.opacity(0.2)), alignment: .top)
    }
    
    private func toggleSelection(for id: String) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if selectedSnippetsForBatch.contains(id) {
            selectedSnippetsForBatch.remove(id)
        } else {
            selectedSnippetsForBatch.insert(id)
        }
    }
    
    private func deleteSelectedSnippets() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        let annotationsToDelete = allAnnotations.filter { selectedSnippetsForBatch.contains($0.id) }
        try? ReadingDataService.shared.deleteAnnotations(annotationsToDelete, context: modelContext)
        withAnimation {
            isBatchEditMode = false
            selectedSnippetsForBatch.removeAll()
        }
    }
    
    private func deleteSnippet(_ id: String) {
        if let target = allAnnotations.first(where: { $0.id == id }) {
            try? ReadingDataService.shared.deleteAnnotation(target, context: modelContext)
        }
    }
}

// ============================================================================
// MARK: - ✨ 4. 辅助卡片组件
// ============================================================================

struct MobileInspirationStatsHeader: View {
    let totalSnippets: Int
    let totalSnippetCharacters: Int
    let uniqueBooksCount: Int
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let formattedKCount = String(format: "%.1f", Double(totalSnippetCharacters) / 1000.0)
        
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(totalSnippetCharacters > 1000 ? formattedKCount : "\(totalSnippetCharacters)").font(.system(size: 28, weight: .heavy, design: .serif)).foregroundColor(.primary)
                    if totalSnippetCharacters > 1000 { Text("k").font(.system(size: 14, weight: .bold)).foregroundColor(.indigo) }
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

struct MobileUnifiedSnippetCardView: View {
    let snippet: InspirationSnippet
    let isMasonry: Bool
    let isBatchEditMode: Bool
    let isSelected: Bool
    let onToggleSelect: () -> Void
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                if isBatchEditMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .blue : .secondary.opacity(0.3))
                }
                
                Image(systemName: snippet.isNote ? "quote.opening" : "text.quote")
                    .font(.system(size: isMasonry ? 20 : 16))
                    .foregroundColor((snippet.isNote ? Color.orange : Color.indigo).opacity(0.8))
                
                Spacer()
                
                if !isMasonry {
                    Text(snippet.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.trailing, 4)
                }
                
                Text(snippet.isNote ? "思考" : "摘录")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(snippet.isNote ? .orange : .indigo)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((snippet.isNote ? Color.orange : Color.indigo).opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Text(LocalizedStringKey(snippet.content))
                .font(.system(size: 15, weight: .medium, design: .serif))
                .lineSpacing(6)
                .foregroundColor(.primary.opacity(0.9))
                .lineLimit(isMasonry ? 12 : nil)
            
            if isMasonry {
                Divider().opacity(0.5).padding(.vertical, 2)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("《\(snippet.bookTitle)》")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary).lineLimit(1)
                        Text(snippet.date.formatted(date: .numeric, time: .omitted))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if !isBatchEditMode {
                        ellipsisMenu()
                    }
                }
            } else {
                if !isBatchEditMode {
                    HStack {
                        Spacer()
                        ellipsisMenu()
                    }
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
        .overlay(RoundedRectangle(cornerRadius: isMasonry ? AppRadius.card : AppRadius.m).stroke(isSelected ? Color.blue : Color.primary.opacity(0.05), lineWidth: isSelected ? 2 : 1))
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 3)
        .contextMenu {
            Button {
                UIPasteboard.general.string = "\"\(snippet.content)\"\n—— 《\(snippet.bookTitle)》"
            } label: { Label("一键拷贝", systemImage: "doc.on.doc") }
            Button(role: .destructive) { onDelete() } label: { Label("删除片段", systemImage: "trash") }
        }
        .onTapGesture {
            if isBatchEditMode {
                onToggleSelect()
            }
        }
    }
    
    private func ellipsisMenu() -> some View {
        Menu {
            Button {
                UIPasteboard.general.string = "\"\(snippet.content)\"\n—— 《\(snippet.bookTitle)》"
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

extension MobileInspirationType {
    var annotationType: AnnotationType? {
        switch self {
        case .all:
            return nil
        case .excerpt:
            return .excerpt
        case .note:
            return .note
        }
    }
}

extension MobileInspirationSort {
    var annotationSortKey: AnnotationSortKey {
        switch self {
        case .newest:
            return .newest
        case .oldest:
            return .oldest
        }
    }
}
#endif
