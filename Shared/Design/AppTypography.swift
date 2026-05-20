#if os(macOS) || os(iOS)
import SwiftUI

enum AppTypography {
    static let displayLarge = Font.system(size: 48, weight: .semibold)
    static let displayMedium = Font.system(size: 36, weight: .semibold)
    static let pageTitle = Font.system(size: 32, weight: .semibold)
    static let titleLarge = Font.system(size: 28, weight: .semibold)
    static let titleMedium = Font.system(size: 22, weight: .semibold)
    static let titleSmall = Font.system(size: 18, weight: .medium)
    static let body = Font.system(size: 15, weight: .regular)
    static let bodySmall = Font.system(size: 13, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
    static let micro = Font.system(size: 11, weight: .medium)
}
#endif
