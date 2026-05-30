#if os(macOS) || os(iOS)
import SwiftUI

enum ReadingProgressInputMode {
    case bookImport
    case sessionUpdate
}

struct ReadingProgressInputView: View {
    @Binding var draft: ReadingProgressDraft

    let mode: ReadingProgressInputMode
    let lockedUnit: Bool
    let minimumCurrentAmount: Double

    init(
        draft: Binding<ReadingProgressDraft>,
        mode: ReadingProgressInputMode,
        lockedUnit: Bool = false,
        minimumCurrentAmount: Double = 0
    ) {
        self._draft = draft
        self.mode = mode
        self.lockedUnit = lockedUnit
        self.minimumCurrentAmount = minimumCurrentAmount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            switch mode {
            case .bookImport:
                importFields
            case .sessionUpdate:
                sessionFields
            }
        }
        .onAppear { draft.normalize() }
    }

    @ViewBuilder
    private var importFields: some View {
        amountField(title: "总页数", suffix: "页", value: totalBinding)
    }

    @ViewBuilder
    private var sessionFields: some View {
        amountField(title: "读到页码", suffix: "页 / \(Int(draft.totalAmount))", value: currentBinding)
    }

    private var totalBinding: Binding<Double> {
        Binding {
            draft.totalAmount
        } set: { value in
            draft.totalAmount = max(value.rounded(), 0)
            draft.normalize()
        }
    }

    private var currentBinding: Binding<Double> {
        Binding {
            draft.currentAmount
        } set: { value in
            draft.currentAmount = min(max(value.rounded(), minimumCurrentAmount), draft.totalAmount)
            draft.normalize()
        }
    }

    private func amountField(title: String, suffix: String, value: Binding<Double>) -> some View {
        HStack(spacing: AppSpacing.s) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: AppSpacing.s)

            TextField("0", value: value, format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 72, maxWidth: 110)

            Text(suffix)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, AppSpacing.m)
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .appInnerBlockStyle(cornerRadius: AppRadius.m)
    }
}

#endif
