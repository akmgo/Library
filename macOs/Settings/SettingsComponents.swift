#if os(macOS)
import SwiftUI

// MARK: - 模块标题行组件
struct SettingsHeaderRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(iconColor)
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(.primary)
                Text(subtitle).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
            }
        }
    }
}

// MARK: - 带右侧控制区的通用行组件
struct SettingsControlRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let control: Content
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(iconColor).frame(width: 28, height: 28)
                Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(.primary)
                Text(subtitle).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
            }
            
            Spacer(minLength: 16)
            control
        }
        .padding(.vertical, 6)
    }
}
#endif
