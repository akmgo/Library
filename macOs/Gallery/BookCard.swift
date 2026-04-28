#if os(macOS)
import SwiftData
import SwiftUI

// MARK: - 🎬 响应全局洗牌调度的轻量卡片包装

struct AnimatedCard_Glide: View {
    let book: Book
    let activeTab: String
    
    let isBatchEditMode: Bool
    let gridScale: GalleryGridScale
    
    @Binding var selectedBooksForBatch: Set<String>
    @Binding var selectedBook: Book?
    
    var body: some View {
        GalleryBookCardView(
            book: book, activeTab: activeTab, gridScale: gridScale,
            isBatchEditMode: isBatchEditMode,
            selectedBooksForBatch: $selectedBooksForBatch,
            selectedBook: $selectedBook
        )
        // ✨ 不再有强制延迟动画，卡片现在干净得就像一张白纸，听从上层调遣
    }
}


// MARK: - 📘 核心封面与信息渲染组件

struct GalleryBookCardView: View {
    @Environment(\.modelContext) private var modelContext
    let book: Book
    let activeTab: String
    let gridScale: GalleryGridScale
    let isBatchEditMode: Bool
    
    @Binding var selectedBooksForBatch: Set<String>
    @Binding var selectedBook: Book?
    
    @State private var isHovered = false
    
    var body: some View {
        let isSelected = selectedBooksForBatch.contains(book.id)
        
        VStack(alignment: .leading, spacing: 10 * gridScale.uiScale) {
            // ================= 封面区 =================
            LocalCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                .aspectRatio(2 / 3, contentMode: .fill)
                .frame(width: gridScale.width, height: gridScale.width * 1.5)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3).padding(-2))
                .overlay(alignment: .topTrailing) {
                    if activeTab == ArchiveFilterTab.reading.rawValue && book.status == .reading {
                        progressCapsule(progress: Int(book.progress))
                            .scaleEffect(gridScale.uiScale, anchor: .topTrailing)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isBatchEditMode {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22 * gridScale.uiScale))
                            .foregroundColor(isSelected ? .blue : .white)
                            .shadow(color: .black.opacity(0.2), radius: 2)
                            .padding(10 * gridScale.uiScale)
                    }
                }
                .shadow(color: Color.black.opacity(isHovered ? 0.2 : 0.08), radius: isHovered ? 12 : 4, y: isHovered ? 6 : 2)
                .scaleEffect(isHovered ? 1.03 : 1.0)
                .offset(y: isHovered ? -4 : 0)
                // ✨ 封面的动画保持
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
                .onTapGesture {
                    if isBatchEditMode {
                        let id = book.id
                        if isSelected { selectedBooksForBatch.remove(id) } else { selectedBooksForBatch.insert(id) }
                    } else {
                        withAnimation(.appFluidSpring) { selectedBook = book }
                    }
                }
                .onHover { h in
                    // ✨ 核心修复 1：剥夺封面修改 isHovered 状态的权力！只保留小手光标！
                    if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            
            // ================= 文本信息区 (集成外放的三点菜单) =================
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4 * gridScale.uiScale) {
                    Text(book.title)
                        .font(.system(size: gridScale.titleFont, weight: .bold))
                        .foregroundColor(isHovered ? .accentColor : .primary)
                        .lineLimit(1)
                        .animation(.easeInOut(duration: 0.2), value: isHovered)
                    
                    Text(book.author)
                        .font(.system(size: gridScale.subFont, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                if !isBatchEditMode {
                    Menu {
                        Section("更改状态") {
                            ForEach(AppConstants.statusOptions, id: \.0) { opt in
                                Button("\(opt.1)书籍") { changeStatus(to: opt.0) }
                            }
                        }
                        Divider()
                        Button(role: .destructive) {
                            modelContext.delete(book); try? modelContext.save()
                            NotificationCenter.default.post(name: .libraryDidUpdate, object: nil)
                        } label: { Label("删除此书", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14 * gridScale.uiScale, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 24 * gridScale.uiScale, height: 20 * gridScale.uiScale, alignment: .topTrailing)
                            .contentShape(Rectangle())
                    }
                    .menuIndicator(.hidden)
                    .menuStyle(.borderlessButton)
                    .opacity(isHovered ? 1 : 0)
                    // ✨ 核心修复 2：防止隐身状态下的误触
                    .allowsHitTesting(isHovered)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            
            // ================= 底部统计区 =================
            if activeTab == ArchiveFilterTab.finished.rawValue && book.status == .finished {
                GalleryStatsView(book: book, gridScale: gridScale)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .frame(width: gridScale.width)
        .contentShape(Rectangle())
        // ✨ 核心修复 3：全局 Hover 状态在此处统一接管
        .onHover { h in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { isHovered = h }
        }
    }
    
    private func changeStatus(to newStatus: BookStatus) {
        book.status = newStatus; try? modelContext.save()
        NotificationCenter.default.post(name: .libraryDidUpdate, object: nil)
    }
    
    private func progressCapsule(progress: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "book.pages").font(.system(size: 9, weight: .bold))
            Text("\(progress)%").font(.system(size: 11, weight: .black, design: .rounded))
        }
        .foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color.black.opacity(0.65)).background(.ultraThinMaterial).clipShape(Capsule()).padding(8)
    }
}

// MARK: - 已读统计详情组件

struct GalleryStatsView: View {
    let book: Book
    let gridScale: GalleryGridScale
    // ❌ 移除了局部的 ratingTexts 数组属性
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6 * gridScale.uiScale) {
            Divider().padding(.top, 4 * gridScale.uiScale)
            
            HStack(alignment: .center) {
                HStack(spacing: 2) {
                    if book.rating > 0 {
                        ForEach(1 ... 7, id: \.self) { i in
                            Image(systemName: "star.fill").font(.system(size: 10 * gridScale.uiScale))
                                .foregroundColor(i <= book.rating ? .yellow : Color.secondary.opacity(0.2))
                        }
                    } else { Text("暂无评分").font(.system(size: 10 * gridScale.uiScale, weight: .bold)).foregroundColor(.secondary.opacity(0.6)) }
                }
                Spacer()
                if book.rating > 0 && book.rating < AppConstants.ratingPoeticTexts.count {
                    // ✨ 统一读取 AppConstants 中的文案
                    Text(AppConstants.ratingPoeticTexts[book.rating]).font(.system(size: 10 * gridScale.uiScale, weight: .bold)).foregroundColor(.orange).lineLimit(1)
                }
            }
            
            HStack(alignment: .center) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.system(size: 10 * gridScale.uiScale))
                    Text("\(formatShortDate(book.startTime)) - \(formatShortDate(book.endTime))")
                        .font(.system(size: 10 * gridScale.uiScale, weight: .bold)).lineLimit(1)
                }.foregroundColor(.secondary)
                
                Spacer()
                Text("历时 \(calculateDays(start: book.startTime, end: book.endTime)) 天")
                    .font(.system(size: 10 * gridScale.uiScale, weight: .bold)).foregroundColor(.blue)
                    .padding(.horizontal, 6 * gridScale.uiScale).padding(.vertical, 2 * gridScale.uiScale)
                    .background(Color.blue.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 4)).lineLimit(1)
            }
            
            if !book.tags.isEmpty {
                ViewThatFits {
                    HStack(spacing: 6 * gridScale.uiScale) {
                        ForEach(Array(book.tags.prefix(3)), id: \.self) { tag in
                            Text(tag).font(.system(size: 9 * gridScale.uiScale, weight: .bold)).foregroundColor(.secondary).textCase(.uppercase)
                                .padding(.horizontal, 6 * gridScale.uiScale).padding(.vertical, 3 * gridScale.uiScale)
                                .background(Color(nsColor: .controlBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        }
                    }
                    HStack(spacing: 6 * gridScale.uiScale) {
                        if let firstTag = book.tags.first {
                            Text(firstTag).font(.system(size: 9 * gridScale.uiScale, weight: .bold)).foregroundColor(.secondary).textCase(.uppercase)
                                .padding(.horizontal, 6 * gridScale.uiScale).padding(.vertical, 3 * gridScale.uiScale)
                                .background(Color(nsColor: .controlBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        }
                    }
                }.padding(.top, 2)
            }
        }
    }
    
    private func formatShortDate(_ date: Date?) -> String {
        guard let d = date else { return "?" }
        // ✨ 使用中央格式化引擎的高性能单例，杜绝重复创建 DateFormatter
        return AppFormatters.slashDateFormatter.string(from: d)
    }

    private func calculateDays(start: Date?, end: Date?) -> Int {
        guard let s = start, let e = end else { return 1 }
        let c = Calendar.current
        let diff = c.dateComponents([.day], from: c.startOfDay(for: s), to: c.startOfDay(for: e)).day ?? 0
        return max(1, diff + 1)
    }
}
#endif
