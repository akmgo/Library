#if os(macOS) || os(iOS)
import SwiftUI

struct DetailSectionHeader<Trailing: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.s) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(tint)

            Spacer(minLength: AppSpacing.s)

            trailing()
        }
    }
}

extension DetailSectionHeader where Trailing == EmptyView {
    init(title: String, systemImage: String, tint: Color) {
        self.init(title: title, systemImage: systemImage, tint: tint) {
            EmptyView()
        }
    }
}
#endif
