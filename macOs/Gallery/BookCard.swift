#if os(macOS)
import SwiftData
import SwiftUI

// MARK: - 🎬 响应全局洗牌调度的轻量卡片包装

struct AnimatedCardGlide: View {
    let book: Book
    let activeTab: String
    
    let isBatchEditMode: Bool
    let gridScale: GalleryGridScale
    
    @Binding var selectedBooksForBatch: Set<String>
    @Binding var selectedBook: Book?
    
    var body: some View {
        BookCard(
            book: book, activeTab: activeTab, gridScale: gridScale,
            isBatchEditMode: isBatchEditMode,
            selectedBooksForBatch: $selectedBooksForBatch,
            selectedBook: $selectedBook
        )
    }
}

// MARK: - 📘 核心封面与信息渲染组件

struct BookCard: View {
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
            BookCoverView(coverID: book.id, coverData: book.coverData, fallbackTitle: book.title)
                .aspectRatio(2 / 3, contentMode: .fill)
                .frame(width: gridScale.width, height: gridScale.width * 1.5)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.bookCover, style: .continuous).stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3).padding(-2))
                .overlay(alignment: .topTrailing) {
                    if activeTab == GalleryFilterTab.reading.rawValue && book.status == .reading {
                        progressCapsule(progress: book.progressRatio)
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
                    if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            
            // ================= 文本信息区 =================
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
                        Button {
                            withAnimation(.appFluidSpring) { selectedBook = book }
                        } label: {
                            Label("查看书籍详情", systemImage: "info.circle")
                        }
                        
                        Divider()
                        
                        Section("更改状态") {
                            ForEach(AppConstants.statusOptions, id: \.0) { opt in
                                Button("\(opt.1)书籍") { changeStatus(to: opt.0) }
                            }
                        }
                        Divider()
                        Button(role: .destructive) {
                            LocalBookManager.shared.deleteBook(book, context: modelContext)
                            try? modelContext.save()
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
                    .allowsHitTesting(isHovered)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            
            // ================= 底部统计区 =================
            if activeTab == GalleryFilterTab.finished.rawValue && book.status == .finished {
                GalleryStatsView(book: book, gridScale: gridScale)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .frame(width: gridScale.width)
        .contentShape(Rectangle())
        .onHover { h in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { isHovered = h }
        }
    }
    
    private func changeStatus(to newStatus: BookStatus) {
        book.status = newStatus; try? modelContext.save()
    }
    
    private func progressCapsule(progress: Double) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "book.pages").font(.system(size: 9, weight: .bold))
            Text("\(Int(progress * 100))%").font(.system(size: 11, weight: .black, design: .rounded))
        }
        .foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color.black.opacity(0.65)).background(.ultraThinMaterial).clipShape(Capsule()).padding(8)
    }
}

// MARK: - 已读统计详情组件

struct GalleryStatsView: View {
    let book: Book
    let gridScale: GalleryGridScale
    
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
                    Text(AppConstants.ratingPoeticTexts[book.rating]).font(.system(size: 10 * gridScale.uiScale, weight: .bold)).foregroundColor(.orange).lineLimit(1)
                }
            }
            
            HStack(alignment: .center) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.system(size: 10 * gridScale.uiScale))
                    Text("\(formatShortDate(book.startDate)) - \(formatShortDate(book.finishDate))")
                        .font(.system(size: 10 * gridScale.uiScale, weight: .bold)).lineLimit(1)
                }.foregroundColor(.secondary)
                
                Spacer()
                Text("历时 \(calculateDays(start: book.startDate, end: book.finishDate)) 天")
                    .font(.system(size: 10 * gridScale.uiScale, weight: .bold)).foregroundColor(.blue)
                    .padding(.horizontal, 6 * gridScale.uiScale).padding(.vertical, 2 * gridScale.uiScale)
                    .background(Color.blue.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: AppRadius.xs)).lineLimit(1)
            }
            
            if !book.tags.isEmpty {
                ViewThatFits {
                    HStack(spacing: 6 * gridScale.uiScale) {
                        ForEach(Array(book.tags.prefix(3)), id: \.self) { tag in
                            Text(tag).font(.system(size: 9 * gridScale.uiScale, weight: .bold)).foregroundColor(.secondary).textCase(.uppercase)
                                .padding(.horizontal, 6 * gridScale.uiScale).padding(.vertical, 3 * gridScale.uiScale)
                                .background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))
                                .overlay(RoundedRectangle(cornerRadius: AppRadius.xs).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        }
                    }
                    HStack(spacing: 6 * gridScale.uiScale) {
                        if let firstTag = book.tags.first {
                            Text(firstTag).font(.system(size: 9 * gridScale.uiScale, weight: .bold)).foregroundColor(.secondary).textCase(.uppercase)
                                .padding(.horizontal, 6 * gridScale.uiScale).padding(.vertical, 3 * gridScale.uiScale)
                                .background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))
                                .overlay(RoundedRectangle(cornerRadius: AppRadius.xs).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        }
                    }
                }.padding(.top, 2)
            }
        }
    }
    
    private func formatShortDate(_ date: Date?) -> String {
        guard let d = date else { return "?" }
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
