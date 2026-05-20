#if os(macOS) || os(iOS)
import SwiftUI

enum AppShadows {
    static let soft = (color: Color.black.opacity(0.04), radius: CGFloat(16), y: CGFloat(4))
    static let medium = (color: Color.black.opacity(0.06), radius: CGFloat(30), y: CGFloat(8))
    static let elevated = (color: Color.black.opacity(0.10), radius: CGFloat(50), y: CGFloat(18))
    static let softDark = (color: Color.black.opacity(0.24), radius: CGFloat(20), y: CGFloat(6))
    static let mediumDark = (color: Color.black.opacity(0.32), radius: CGFloat(36), y: CGFloat(12))
    static let elevatedDark = (color: Color.black.opacity(0.45), radius: CGFloat(50), y: CGFloat(22))
}
#endif
