#if os(macOS)
import SwiftData
import SwiftUI

private enum ContentEditorInputMetrics {
    static let font = Font.system(size: 15, weight: .regular)
    static let lineSpacing: CGFloat = 6
    static let editorPadding: CGFloat = 16
}

// MARK: - ✨ 内容增改通用弹窗

struct ContentEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    
    let book: Book?
    let mode: BookContentEntryMode
    
    // ✨ 核心修复：接收全新的统一大实体 Excerpt
    var itemToEdit: Excerpt? = nil
    
    @State private var selectedMode: BookContentEntryMode = .excerpt
    @State private var contentText: String = ""
    @Namespace private var modeNamespace
    
    var body: some View {
        let isEdit = itemToEdit != nil
        
        VStack(spacing: 0) {
            // ================= 1. 顶部标题与类型滑块 =================
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: selectedMode.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(selectedMode.tint)

                    Text(isEdit ? "编辑内容" : "添加内容")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                }

                modeSlider
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider().opacity(0.5)
            
            // ================= 2. 核心文本编辑区 =================
            ZStack(alignment: .topLeading) {
                TextEditor(text: $contentText)
                    .font(ContentEditorInputMetrics.font)
                    .lineSpacing(ContentEditorInputMetrics.lineSpacing)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .padding(ContentEditorInputMetrics.editorPadding)

                if contentText.isEmpty {
                    Text(selectedMode.placeholder)
                        .font(ContentEditorInputMetrics.font)
                        .foregroundColor(.secondary.opacity(0.6))
                        .lineSpacing(ContentEditorInputMetrics.lineSpacing)
                        .padding(ContentEditorInputMetrics.editorPadding + 12 + 4)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider().opacity(0.5)
            
            // ================= 3. 底部操作区 =================
            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 6))
                
                let isContentValid = !contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let originalMode: BookContentEntryMode = itemToEdit?.isNote == true ? .note : .excerpt
                let hasChanges = isEdit ? (contentText != itemToEdit?.content || selectedMode != originalMode) : true
                let canSave = isContentValid && hasChanges
                
                Button(isEdit ? "保存修改" : selectedMode.saveTitle) { saveContent() }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .glassEffect(canSave ? .regular.tint(selectedMode.tint).interactive() : .clear.interactive(), in: .rect(cornerRadius: 6))
                    .opacity(canSave ? 1.0 : 0.4)
            }
            .padding(16)
        }
        .frame(width: 540, height: 420)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .background(WindowTransparentEffect())
        .onAppear {
            selectedMode = itemToEdit?.isNote == true ? .note : mode
            if let item = itemToEdit {
                contentText = item.content
            }
        }
    }

    private var modeSlider: some View {
        HStack(spacing: 0) {
            ForEach(BookContentEntryMode.allCases, id: \.self) { mode in
                let isSelected = selectedMode == mode

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedMode = mode
                    }
                } label: {
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.clear)
                                .glassEffect(.regular.tint(mode.tint), in: .rect(cornerRadius: 10))
                                .matchedGeometryEffect(id: "content-mode", in: modeNamespace)
                        }

                        HStack(spacing: 7) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 12, weight: .semibold))
                            Text(mode.displayName)
                                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                        }
                        .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.72))
                        .frame(maxWidth: .infinity, minHeight: 34)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.clear.glassEffect(in: .rect(cornerRadius: 12)))
    }
    
    // MARK: - 存储逻辑
    
    private func saveContent() {
        guard !contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        if let item = itemToEdit {
            // ✨ 编辑模式：直接更新单体字段，逻辑极致简单
            item.content = contentText
            item.category = selectedMode.category
            try? modelContext.save()
        } else if let targetBook = book {
            // ✨ 新增模式：注入明确的 Type
            try? ReadingDataService.shared.insertExcerpt(
                content: contentText,
                category: selectedMode.category,
                book: targetBook,
                context: modelContext
            )
        }
        
        isPresented = false
    }
}

#Preview("通用内容增改弹窗") {
    ContentEditorSheet(isPresented: .constant(true), book: nil, mode: .excerpt)
        .padding(40)
        .background(LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom))
}
#endif
