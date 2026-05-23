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
            if !lockedUnit {
                unitSelector
            } else {
                HStack(spacing: AppSpacing.s) {
                    Image(systemName: draft.unit.systemImage)
                        .foregroundStyle(AppColors.readingAmber)
                    Text(draft.unit.longDisplayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
            }

            switch mode {
            case .bookImport:
                importFields
            case .sessionUpdate:
                sessionFields
            }
        }
        .onAppear { draft.normalize() }
    }

    private var unitSelector: some View {
        HStack(spacing: 0) {
            ForEach(ProgressUnit.allCases, id: \.self) { unit in
                let isSelected = draft.unit == unit

                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        draft.setUnit(unit, currentBookAmount: minimumCurrentAmount)
                    }
                } label: {
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.clear)
                                .glassEffect(.regular.tint(AppColors.readingAmber), in: .rect(cornerRadius: 10))
                        }

                        HStack(spacing: 6) {
                            Image(systemName: unit.systemImage)
                                .font(.system(size: 11, weight: .bold))
                            Text(unit.longDisplayName)
                                .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                        }
                        .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.78))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: 36)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.clear.glassEffect(in: .rect(cornerRadius: 12)))
    }

    private var unitBinding: Binding<ProgressUnit> {
        Binding {
            draft.unit
        } set: { newValue in
            draft.setUnit(newValue, currentBookAmount: minimumCurrentAmount)
        }
    }

    @ViewBuilder
    private var importFields: some View {
        switch draft.unit {
        case .percent:
            progressSummary(title: "总进度", value: "100%")
        case .page:
            amountField(title: "总页数", suffix: "页", value: totalBinding)
        case .chapter:
            amountField(title: "总章节", suffix: "章", value: totalBinding)
        }
    }

    @ViewBuilder
    private var sessionFields: some View {
        switch draft.unit {
        case .percent:
            VStack(alignment: .center, spacing: AppSpacing.s) {
                HStack {
                    Text("读到")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(draft.currentAmount.rounded()))%")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.readingAmber)
                }
                Slider(value: currentBinding, in: minimumCurrentAmount...100, step: 1)
                    .tint(AppColors.readingAmber)
                    .frame(maxWidth: .infinity)
            }
        case .page:
            amountField(title: "读到页码", suffix: "页 / \(Int(draft.totalAmount))", value: currentBinding)
        case .chapter:
            amountField(title: "读到章节", suffix: "章 / \(Int(draft.totalAmount))", value: currentBinding)
        }
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

    private func progressSummary(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppColors.readingAmber)
        }
        .padding(.horizontal, AppSpacing.m)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous))
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
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.m, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

extension ProgressUnit {
    var longDisplayName: String {
        switch self {
        case .percent: return "百分比"
        case .page: return "页码"
        case .chapter: return "章节"
        }
    }

    var systemImage: String {
        switch self {
        case .percent: return "percent"
        case .page: return "doc.text"
        case .chapter: return "list.number"
        }
    }
}
#endif
