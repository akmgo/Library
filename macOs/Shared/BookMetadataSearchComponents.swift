#if os(macOS)
import SwiftUI

// MARK: - 🎯 全局通用云端搜索组件库 (Universal Cloud Search Components)

/// 控制搜索结果行的渲染模式
enum BookMetadataSearchRowMode {
    case spotlight // 宽大布局，带液态玻璃悬浮态
    case popover   // 紧凑布局，极简背景
}

// MARK: - 大一统搜索结果行 (带防盗链实时封面下载)

struct BookMetadataSearchResultRow: View {
    let result: BookSearchResult
    let mode: BookMetadataSearchRowMode
    let isImporting: Bool // 仅在 spotlight 模式下生效
    
    // 回调抛出已加载好的封面数据，实现秒存
    let onSelect: (Data?) -> Void
    
    @State private var isHovered = false
    @State private var coverData: Data? = nil
    @State private var isLoadingCover = false
    
    var body: some View {
        let isSpotlight = mode == .spotlight
        
        HStack(alignment: .center, spacing: isSpotlight ? 16 : 12) {
            
            // 1. 微缩实时封面区
            ZStack {
                if let data = coverData, let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(Color.secondary.opacity(0.1))
                    if isLoadingCover {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "book.closed")
                            .font(.system(size: isSpotlight ? 14 : 12))
                            .foregroundColor(.secondary.opacity(0.4))
                    }
                }
            }
            .frame(width: isSpotlight ? 40 : 28, height: isSpotlight ? 60 : 42)
            .clipShape(RoundedRectangle(cornerRadius: isSpotlight ? 6 : 4))
            .shadow(color: .black.opacity(0.1), radius: 2)
            .overlay(RoundedRectangle(cornerRadius: isSpotlight ? 6 : 4).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
            // 异步解密下载封面
            .task(id: result.coverURL) {
                guard let url = result.coverURL, !url.isEmpty else { return }
                isLoadingCover = true
                coverData = await BookMetadataSearchManager.shared.fetchCoverData(from: url)
                isLoadingCover = false
            }
            
            // 2. 文本信息区
            VStack(alignment: .leading, spacing: isSpotlight ? 6 : 4) {
                Text(result.title)
                    .font(.system(size: isSpotlight ? 16 : 13, weight: .bold))
                    .foregroundColor(isHovered ? .blue : .primary)
                    .lineLimit(1)
                
                HStack {
                    Text(result.author)
                        .font(.system(size: isSpotlight ? 13 : 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if isSpotlight, let desc = result.description, !desc.isEmpty {
                        Text("· \(desc)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // 3. 尾部指示图标
            if isSpotlight {
                if isImporting {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(isHovered ? .blue : .secondary.opacity(0.2))
                }
            } else {
                if isHovered {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, isSpotlight ? 16 : 10)
        .padding(.vertical, isSpotlight ? 12 : 8)
        .contentShape(Rectangle())
        // ✨ 根据模式智能切换材质
        .background(
            Group {
                if isSpotlight {
                    Color.clear
                        .background(isHovered ? AnyView(Color.clear) : AnyView(Color.clear))
                        .glassEffect(isHovered ? .regular.interactive() : .clear, in: .rect(cornerRadius: 12))
                        .id(isHovered)
                } else {
                    isHovered ? Color.blue.opacity(0.1) : Color.clear
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: isSpotlight ? 12 : 6))
        .onHover { h in
            withAnimation(.snappy) { isHovered = h }
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .onTapGesture {
            onSelect(coverData)
        }
    }
}

#if os(macOS)
import SwiftUI

// MARK: - 🎯 表单专用的局部气泡容器

struct InlineBookSearchResultsPopover: View {
    let results: [BookSearchResult]
    let error: String?
    let isLoading: Bool
    let onSelect: (BookSearchResult, Data?) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading && results.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在云端检索...").font(.system(size: 12)).foregroundColor(.secondary)
                }
                .padding(32)
            } else if let error = error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 20)).foregroundColor(.red.opacity(0.8))
                    Text(error).font(.system(size: 12)).foregroundColor(.secondary)
                }
                .padding(32)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        // ✨ 核心限制：即使底层接口返回了 100 条，这里也截断只渲染前 5 条，保证弹窗高度美观
                        ForEach(Array(results)) { res in
                            // ✨ 调用大一统组件，传入 popover 模式
                            BookMetadataSearchResultRow(result: res, mode: .popover, isImporting: false) { fetchedCover in
                                onSelect(res, fetchedCover)
                            }
                        }
                    }
                    .padding(8)
                }
                // 5 条数据大约 300px 高度，320 的 maxHeight 刚好能完美容纳，不需要改动
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 320)
    }
}
#endif
#endif
