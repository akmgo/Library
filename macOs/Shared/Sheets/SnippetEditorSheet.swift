#if os(macOS)
import SwiftData
import SwiftUI

// MARK: - ✨ 纯净丝滑录入弹窗 (高级物理回弹滑块版)
struct SnippetEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    
    var snippetToEdit: Snippet? = nil
    
    @State private var selectedCategory: SnippetCategory = .web
    @State private var titleInput: String = ""
    @State private var contentInput: String = ""
    @State private var authorInput: String = ""
    @State private var dynastyInput: String = ""
    @State private var annotationInput: String = ""
    
    // ✨ 核心动画空间：用于追踪滑块的物理位置
    @Namespace private var categoryAnimation
    
    private var showAuthor: Bool { [.poetry, .lyric, .prose, .quote, .movie].contains(selectedCategory) }
    private var showDynastyAndAnnotation: Bool { [.poetry, .lyric, .prose].contains(selectedCategory) }
    
    var body: some View {
        let isEdit = snippetToEdit != nil
        
        VStack(spacing: 0) {
            // ================= 顶栏 =================
            HStack(spacing: 12) {
                Image(systemName: isEdit ? "text.quote" : "square.and.pencil")
                    .foregroundColor(.primary)
                    .font(.system(size: 20))
                Text(isEdit ? "编辑摘录" : "新增笔墨")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
            }
            .padding(24)
            
            Divider().opacity(0.5)
            
            // ================= 核心大表单区 =================
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // ✨ 高级滑动切换条：物理回弹质感
                    HStack(spacing: 0) {
                        ForEach(SnippetCategory.allCases, id: \.self) { category in
                            Text(category.displayName)
                                .font(.system(size: 15, weight: selectedCategory == category ? .bold : .medium))
                                .foregroundColor(selectedCategory == category ? .white : .primary.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                // 将背景改为 ZStack 承载几何匹配
                                .background(
                                    ZStack {
                                        if selectedCategory == category {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(Color.accentColor)
                                                // 告诉 SwiftUI 这个滑块要在不同选项之间飞梭
                                                .matchedGeometryEffect(id: "ActiveTabIndicator", in: categoryAnimation)
                                        }
                                    }
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // 🍎 苹果级别的物理弹簧参数：
                                    // response 控制速度 (0.35秒)，dampingFraction 控制回弹阻尼 (0.65 带来极度舒适的微弹感)
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65, blendDuration: 0.2)) {
                                        selectedCategory = category
                                    }
                                }
                        }
                    }
                    .padding(6)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onChange(of: selectedCategory) { _, newValue in
                        if newValue == .web {
                            authorInput = ""; dynastyInput = ""; annotationInput = ""
                        } else if [.quote, .movie].contains(newValue) {
                            dynastyInput = ""; annotationInput = ""
                        }
                    }
                    
                    // 标题行
                    inputRow(label: selectedCategory == .movie ? "出处" : "标题",
                             placeholder: selectedCategory == .movie ? "例如：星际穿越" : "例如：将进酒", text: $titleInput)
                    
                    // 作者/朝代行
                    if showAuthor {
                        HStack(spacing: 24) {
                            inputRow(label: selectedCategory == .movie ? "角色" : "作者",
                                     placeholder: selectedCategory == .movie ? "例如：库珀" : "例如：李白", text: $authorInput)
                            if showDynastyAndAnnotation {
                                inputRow(label: "朝代", placeholder: "例如：唐", text: $dynastyInput)
                            }
                        }
                    }
                    
                    // 正文输入区
                    VStack(alignment: .leading, spacing: 10) {
                        Text(selectedCategory == .movie ? "台词正文" : "内容正文")
                            .foregroundColor(.secondary).font(.system(size: 15))
                        ZStack(alignment: .topLeading) {
                            if contentInput.isEmpty {
                                Text("请输入内容，支持换行...")
                                    .foregroundColor(.secondary.opacity(0.4))
                                    .font(.system(size: 18, design: .serif))
                                    .padding(.horizontal, 12).padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $contentInput)
                                .font(.system(size: 18, design: .serif))
                                .scrollContentBackground(.hidden)
                                .padding(8)
                        }
                        .frame(minHeight: 220, alignment: .top)
                        .glassEffect(in: .rect(cornerRadius: 10))
                    }
                    
                    // 注释区
                    if showDynastyAndAnnotation {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("注释/释义").foregroundColor(.secondary).font(.system(size: 15))
                            ZStack(alignment: .topLeading) {
                                if annotationInput.isEmpty {
                                    Text("选填...")
                                        .foregroundColor(.secondary.opacity(0.4))
                                        .font(.system(size: 16))
                                        .padding(.horizontal, 12).padding(.vertical, 12)
                                        .allowsHitTesting(false)
                                }
                                TextEditor(text: $annotationInput)
                                    .font(.system(size: 16))
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                            }
                            .frame(minHeight: 100, alignment: .top)
                            .glassEffect(in: .rect(cornerRadius: 10))
                        }
                    }
                }
                .padding(32)
            }
            
            Divider().opacity(0.5)
            
            // ================= 底部操作按钮 =================
            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .font(.system(size: 15))
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
                
                let canSave = !titleInput.trimmingCharacters(in: .whitespaces).isEmpty && !contentInput.trimmingCharacters(in: .whitespaces).isEmpty
                
                Button(isEdit ? "保存修改" : "确认录入") { saveSnippet() }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
                    .font(.system(size: 15, weight: .bold))
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .glassEffect(canSave ? .regular.tint(selectedCategory.themeColor).interactive() : .clear.interactive(), in: .rect(cornerRadius: 8))
                    .opacity(canSave ? 1.0 : 0.4)
            }
            .padding(20)
        }
        .frame(width: 680, height: 700)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .background(WindowTransparentEffect())
        .onAppear {
            if let snippet = snippetToEdit {
                selectedCategory = snippet.category; titleInput = snippet.title; contentInput = snippet.content
                authorInput = snippet.author; dynastyInput = snippet.dynasty; annotationInput = snippet.annotation
            }
        }
    }
    
    private func inputRow(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label).foregroundColor(.secondary).font(.system(size: 15))
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .padding(.horizontal, 16).padding(.vertical, 14)
                .glassEffect(in: .rect(cornerRadius: 10))
        }
    }
    
    private func saveSnippet() {
        guard !titleInput.isEmpty, !contentInput.isEmpty else { return }
        
        if let snippet = snippetToEdit {
            snippet.category = selectedCategory; snippet.title = titleInput; snippet.content = contentInput
            snippet.author = showAuthor ? (authorInput.isEmpty ? "佚名" : authorInput) : "佚名"
            snippet.dynasty = showDynastyAndAnnotation ? dynastyInput : ""
            snippet.annotation = showDynastyAndAnnotation ? annotationInput : ""
        } else {
            let newSnippet = Snippet(title: titleInput, content: contentInput, author: showAuthor ? (authorInput.isEmpty ? "佚名" : authorInput) : "佚名", dynasty: showDynastyAndAnnotation ? dynastyInput : "", annotation: showDynastyAndAnnotation ? annotationInput : "", category: selectedCategory)
            modelContext.insert(newSnippet)
        }
        
        try? modelContext.save()
        isPresented = false
    }
}

#Preview("大字号录入弹窗") {
    let schema = Schema([Snippet.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    SnippetEditorSheet(isPresented: .constant(true))
        .padding(60)
        .background(Color.blue.opacity(0.3))
        .modelContainer(container)
}
#endif
