#if os(iOS)
import SwiftData
import SwiftUI

// MARK: - ✨ iOS 原生录入弹窗
struct MobileExcerptEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    
    var excerptToEdit: Excerpt? = nil
    
    @State private var selectedCategory: ExcerptCategory = .web
    @State private var titleInput: String = ""
    @State private var contentInput: String = ""
    @State private var authorInput: String = ""
    @State private var dynastyInput: String = ""
    @State private var annotationInput: String = ""
    
    // 控制键盘焦点
    @FocusState private var focusedField: Field?
    enum Field { case title, author, dynasty, content, annotation }
    
    private var showAuthor: Bool { [.poetry, .lyric, .prose, .quote, .movie].contains(selectedCategory) }
    private var showDynastyAndAnnotation: Bool { [.poetry, .lyric, .prose].contains(selectedCategory) }
    
    // 计算是否允许保存
    private var canSave: Bool {
        !titleInput.trimmingCharacters(in: .whitespaces).isEmpty && !contentInput.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // ================= 1. 分类选择区 =================
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ExcerptCategory.allCases, id: \.self) { category in
                                Text(category.displayName)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(selectedCategory == category ? .white : .primary.opacity(0.7))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == category ? category.themeColor : Color(uiColor: .tertiarySystemGroupedBackground))
                                    .clipShape(Capsule())
                                    .onTapGesture {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            selectedCategory = category
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets()) // 移除 Form 默认边距，让滚动铺满
                    .listRowBackground(Color.clear)
                }
                
                // ================= 2. 基础信息区 =================
                Section(header: Text("基础信息")) {
                    TextField(selectedCategory == .movie ? "出处 (例如：星际穿越)" : "标题 (例如：将进酒)", text: $titleInput)
                        .font(.system(size: 16))
                        .focused($focusedField, equals: .title)
                    
                    if showAuthor {
                        TextField(selectedCategory == .movie ? "角色 (例如：库珀)" : "作者 (例如：李白)", text: $authorInput)
                            .font(.system(size: 16))
                            .focused($focusedField, equals: .author)
                    }
                    
                    if showDynastyAndAnnotation {
                        TextField("朝代 (选填，例如：唐)", text: $dynastyInput)
                            .font(.system(size: 16))
                            .focused($focusedField, equals: .dynasty)
                    }
                }
                
                // ================= 3. 核心内容区 =================
                Section(header: Text(selectedCategory == .movie ? "台词正文" : "内容正文")) {
                    ZStack(alignment: .topLeading) {
                        if contentInput.isEmpty {
                            Text("请输入内容，支持换行...")
                                .foregroundColor(Color(uiColor: .placeholderText))
                                .font(.system(size: 16, design: .serif))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false) // 让点击穿透到下方的 TextEditor
                        }
                        TextEditor(text: $contentInput)
                            .font(.system(size: 16, design: .serif))
                            .frame(minHeight: 180)
                            .focused($focusedField, equals: .content)
                    }
                }
                
                // ================= 4. 注释区 =================
                if showDynastyAndAnnotation {
                    Section(header: Text("注释 / 释义 (选填)")) {
                        ZStack(alignment: .topLeading) {
                            if annotationInput.isEmpty {
                                Text("输入对文字的注解...")
                                    .foregroundColor(Color(uiColor: .placeholderText))
                                    .font(.system(size: 15))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $annotationInput)
                                .font(.system(size: 15))
                                .frame(minHeight: 100)
                                .focused($focusedField, equals: .annotation)
                        }
                    }
                }
            }
            .navigationTitle(excerptToEdit != nil ? "编辑摘录" : "新增笔墨")
            .navigationBarTitleDisplayMode(.inline)
            // ================= 顶部操作栏 =================
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(excerptToEdit != nil ? "保存" : "添加") {
                        saveExcerpt()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(canSave ? selectedCategory.themeColor : .secondary.opacity(0.4))
                    .disabled(!canSave)
                }
                
                // 给键盘上方增加一个“完成”收起的工具栏
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("完成") {
                            focusedField = nil
                        }
                        .font(.system(size: 16, weight: .bold))
                    }
                }
            }
            .onAppear {
                if let excerpt = excerptToEdit {
                    selectedCategory = excerpt.category
                    titleInput = excerpt.title ?? ""
                    contentInput = excerpt.content
                    authorInput = excerpt.author
                    dynastyInput = excerpt.dynasty
                    annotationInput = excerpt.annotation
                } else {
                    // 如果是新增，默认自动弹出键盘激活标题输入
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        focusedField = .title
                    }
                }
            }
            .onChange(of: selectedCategory) { _, newValue in
                if newValue == .web {
                    authorInput = ""; dynastyInput = ""; annotationInput = ""
                } else if [.quote, .movie].contains(newValue) {
                    dynastyInput = ""; annotationInput = ""
                }
            }
        }
    }
    
    // MARK: - 数据保存引擎
    private func saveExcerpt() {
        guard !titleInput.isEmpty, !contentInput.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        if let excerpt = excerptToEdit {
            excerpt.category = selectedCategory
            excerpt.title = titleInput
            excerpt.content = contentInput
            excerpt.author = showAuthor ? (authorInput.trimmingCharacters(in: .whitespaces).isEmpty ? "佚名" : authorInput) : "佚名"
            excerpt.dynasty = showDynastyAndAnnotation ? dynastyInput : ""
            excerpt.annotation = showDynastyAndAnnotation ? annotationInput : ""
        } else {
            let newExcerpt = Excerpt(
                title: titleInput,
                content: contentInput,
                author: showAuthor ? (authorInput.trimmingCharacters(in: .whitespaces).isEmpty ? "佚名" : authorInput) : "佚名",
                dynasty: showDynastyAndAnnotation ? dynastyInput : "",
                annotation: showDynastyAndAnnotation ? annotationInput : "",
                category: selectedCategory
            )
            try? ReadingDataService.shared.insertExcerpt(newExcerpt, context: modelContext)
        }
        
        if excerptToEdit != nil { try? modelContext.save() }
        isPresented = false
    }
}

// MARK: - 📱 预览
#Preview("日常摘录录入弹窗") {
    let schema = Schema([Excerpt.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    MobileExcerptEditorSheet(isPresented: .constant(true))
        .modelContainer(container)
}
#endif
