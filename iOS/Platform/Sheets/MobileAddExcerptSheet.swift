#if os(iOS)
import SwiftUI
import SwiftData

private enum MobileBookContentInputMetrics {
    static let font = Font.system(size: 17, weight: .regular, design: .serif)
    static let lineSpacing: CGFloat = 6
    static let editorPadding: CGFloat = 14
}

// MARK: - 📝 摘录 / 笔记录入表单

/// 书籍详情页内的轻量级内容录入表单。
struct MobileAddExcerptSheet: View {
    let book: Book
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedMode: BookContentEntryMode = .excerpt
    @State private var content: String = ""
    @FocusState private var isFocused: Bool

    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: AppSpacing.l) {
                    modeSlider
                    contentEditor
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.emptyState)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppColors.primaryBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle("添加内容")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isFocused = false
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(selectedMode.saveTitle) { saveExcerpt() }
                        .fontWeight(.bold)
                        .disabled(trimmedContent.isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isFocused = true }
            }
        }
    }

    private var modeSlider: some View {
        AppSlidingSegmentedControl(
            selection: $selectedMode,
            options: BookContentEntryMode.allCases.map {
                AppSlidingSegmentedOption(value: $0, title: $0.displayName, systemImage: $0.iconName)
            },
            tint: AppColors.selection,
            height: 32,
            cornerRadius: AppRadius.m
        )
    }

    private var contentEditor: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(selectedMode.contentLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text(selectedMode.placeholder)
                        .foregroundStyle(.secondary.opacity(0.55))
                        .font(MobileBookContentInputMetrics.font)
                        .lineSpacing(MobileBookContentInputMetrics.lineSpacing)
                        .padding(MobileBookContentInputMetrics.editorPadding)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $content)
                    .font(MobileBookContentInputMetrics.font)
                    .lineSpacing(MobileBookContentInputMetrics.lineSpacing)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .padding(MobileBookContentInputMetrics.editorPadding)
            }
            .frame(minHeight: 260, alignment: .top)
            .background(
                AppColors.innerBlock(for: colorScheme)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
    }
    
    private func saveExcerpt() {
        if !trimmedContent.isEmpty {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            try? ReadingDataService.shared.insertExcerpt(
                content: trimmedContent,
                category: selectedMode.category,
                book: book,
                context: modelContext
            )
            dismiss()
        }
    }
}

#if DEBUG
private struct PreviewAddExcerpt: View {
    var body: some View {
        PreviewWithBook { book in
            PreviewSheet {
                MobileAddExcerptSheet(book: book)
            }
        }
    }
}

#Preview("摘录录入弹窗") {
    PreviewAddExcerpt()
        .modelContainer(previewModelContainer)
}
#endif


#endif
