#if os(macOS)
import AppKit
import CoreImage
import SwiftData
import SwiftUI

// MARK: - ✨ 书籍详情主容器

/// macOS 端专属的书籍全景详情页。
struct BookDetailView: View {
    let book: Book
    @Binding var selectedBook: Book?
    @Environment(\.modelContext) private var modelContext
    
    // ✨ 状态上提：外层控制编辑和删除的弹出
    @Binding var showEditSheet: Bool
    @Binding var showDeleteAlert: Bool
    
    @State private var showAddExcerptSheet = false
    @State private var showAddNoteSheet = false
    @State private var isDeleteMode = false
    
    /// ✨ 接收异步提取的封面主题色
    @State private var themeColor: Color? = nil
    
    var body: some View {
        ZStack(alignment: .top) {
            // ================= 1. 沉浸式专属液态背景 =================
            // 🛑 核心修复：调用全局流体画幕，它的实体底板会完美遮挡背后的列表，
            // 同时它的网格渐变会继续为详情页的玻璃组件提供流动折射光源！
            AmbientFluidCanvas()
                .contentShape(Rectangle()) // 确保整面墙都能接收点击
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { selectedBook = nil }
                }
            
            // ✨ 专属光晕：提取封面主色调，叠加在流动极光之上，形成从顶部倾泻而下的柔和折射光源
            if let themeColor {
                LinearGradient(
                    colors: [
                        themeColor.opacity(0.35),
                        themeColor.opacity(0.1),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .transition(.opacity)
                .allowsHitTesting(false) // 让点击穿透到下层的返回热区
            }
            
            // ================= 2. 全局无界内容区 =================
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 80) {
                    // 👆 上大模块
                    BookDossierView(book: book)
                        .zIndex(1)
                    
                    // 👇 下大模块
                    VStack(spacing: 30) {
                        VStack(spacing: 16) {
                            HStack(alignment: .center) {
                                Text("思考的痕迹")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                HStack(spacing: 12) {
                                    ProminentActionButton(
                                        title: isDeleteMode ? "完成" : "管理",
                                        systemImage: isDeleteMode ? "checkmark" : "trash",
                                        tintColor: isDeleteMode ? .blue : .gray,
                                        action: { withAnimation(.spring()) { isDeleteMode.toggle() } }
                                    )
                                    .glassEffect(isDeleteMode ? .regular.tint(.blue).interactive() : .regular.interactive(), in: .capsule)
                                    
                                    ProminentActionButton(
                                        title: "笔记",
                                        systemImage: "square.and.pencil",
                                        tintColor: .purple,
                                        action: { showAddNoteSheet = true }
                                    )
                                    .glassEffect(.regular.tint(.purple).interactive(), in: .capsule)
                                    
                                    ProminentActionButton(
                                        title: "摘录",
                                        systemImage: "quote.opening",
                                        tintColor: .indigo,
                                        action: { showAddExcerptSheet = true }
                                    )
                                    .glassEffect(.regular.tint(.indigo).interactive(), in: .capsule)
                                }
                            }
                            Divider()
                        }
                        
                        BookExcerptsView(
                            book: book,
                            isDeleteMode: isDeleteMode,
                            onDelete: { itemToDelete in deleteRecord(itemToDelete) }
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 100)
                .padding(.top, 100)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // ================= 3. 弹窗引擎池 =================
            .sheet(isPresented: $showAddExcerptSheet) {
                ContentEditorSheet(isPresented: $showAddExcerptSheet, book: book, mode: .excerpt)
            }
            .sheet(isPresented: $showAddNoteSheet) {
                ContentEditorSheet(isPresented: $showAddNoteSheet, book: book, mode: .note)
            }
        }
        // ✨ 当进入详情页或封面变化时，激活主题色嗅探引擎
        .task(id: book.coverData) {
            await extractThemeColor()
        }
        .sheet(isPresented: $showEditSheet) {
            BookEditorSheet(isPresented: $showEditSheet, bookToEdit: book)
        }
        .alert("删除书籍", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("确认删除", role: .destructive) {
                // 1. 立即清空选中状态（触发详情页关闭动画）
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    selectedBook = nil
                }
                
                // 2. 延迟执行删除（等待关闭动画完成），并强制同步
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    modelContext.delete(book)
                    
                    do {
                        // ✨ 核心操作：强制持久化到磁盘，确保画廊读取的是最新状态
                        try modelContext.save()
                        
                        // ✨ 核心操作：发送全局信号，告诉画廊“该干活了”
                        NotificationCenter.default.post(name: .libraryDidUpdate, object: nil)
                        
                        print("✅ 书籍已成功从磁盘删除并通知画廊")
                    } catch {
                        print("❌ 删除保存失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - ✨ 封面色彩提取引擎
    
    private func extractThemeColor() async {
        guard let data = book.coverData, let ciImage = CIImage(data: data) else {
            await MainActor.run { themeColor = nil }
            return
        }
        
        let extentVector = CIVector(x: ciImage.extent.origin.x, y: ciImage.extent.origin.y, z: ciImage.extent.size.width, w: ciImage.extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extentVector]),
              let outputImage = filter.outputImage
        else {
            return
        }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.8)) {
                self.themeColor = Color(red: Double(bitmap[0]) / 255.0, green: Double(bitmap[1]) / 255.0, blue: Double(bitmap[2]) / 255.0)
            }
        }
    }
    
    // MARK: - 记录销毁逻辑 (✨ 升级为单一模型 BookAnnotation)
    
    private func deleteRecord(_ item: BookAnnotation) {
        withAnimation(.spring()) {
            // 直接删除该实体，无需再走 switch 缝合逻辑
            modelContext.delete(item)
        }
        
        // 统计这本树下所有的批注数量（合并后的表）
        let totalCount = book.annotations?.count ?? 0
        if totalCount <= 1 {
            withAnimation { isDeleteMode = false }
        }
    }
}

// MARK: - ✨ 预览装配

struct BookDetailPreviewWrapper: View {
    @Query var books: [Book]
    @State private var selectedBook: Book?
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        if let book = books.first {
            BookDetailView(
                book: book,
                selectedBook: $selectedBook,
                showEditSheet: $showEditSheet,
                showDeleteAlert: $showDeleteAlert
            )
            .frame(width: 1000, height: 800)
            .onAppear { selectedBook = book }
        } else {
            Text("加载假数据中...")
        }
    }
}

#Preview("全景：书籍详情主页面") {
    BookDetailPreviewWrapper()
        .modelContainer(PreviewData.shared)
}
#endif
