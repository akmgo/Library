#if os(macOS) || os(iOS)
import SwiftUI

enum AppColors {
    enum Light {
        static let primaryBackground = Color(red: 247 / 255, green: 245 / 255, blue: 241 / 255)
        static let secondaryBackground = Color.white
        static let tertiaryBackground = Color(red: 238 / 255, green: 234 / 255, blue: 227 / 255)
        static let primaryText = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
        static let secondaryText = Color(red: 110 / 255, green: 110 / 255, blue: 115 / 255)
        static let tertiaryText = Color(red: 161 / 255, green: 161 / 255, blue: 166 / 255)
        static let accentSoft = Color(red: 241 / 255, green: 228 / 255, blue: 208 / 255)
    }

    enum Dark {
        static let primaryBackground = Color(red: 17 / 255, green: 17 / 255, blue: 19 / 255)
        static let secondaryBackground = Color(red: 26 / 255, green: 26 / 255, blue: 29 / 255)
        static let tertiaryBackground = Color(red: 36 / 255, green: 36 / 255, blue: 40 / 255)
        static let primaryText = Color(red: 245 / 255, green: 245 / 255, blue: 247 / 255)
        static let secondaryText = Color(red: 161 / 255, green: 161 / 255, blue: 166 / 255)
        static let tertiaryText = Color(red: 111 / 255, green: 111 / 255, blue: 118 / 255)
        static let accentSoft = Color(red: 58 / 255, green: 43 / 255, blue: 25 / 255)
    }

    static let readingAmber = Color(red: 200 / 255, green: 155 / 255, blue: 90 / 255)
    static let success = Color(red: 111 / 255, green: 175 / 255, blue: 140 / 255)
    static let warning = Color(red: 214 / 255, green: 160 / 255, blue: 79 / 255)
    static let danger = Color(red: 217 / 255, green: 108 / 255, blue: 108 / 255)
    static let selection = readingAmber
    static let progress = readingAmber
    static let excerpt = readingAmber
    static let note = warning

    static func primaryBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Dark.primaryBackground : Light.primaryBackground
    }

    static func secondaryBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Dark.secondaryBackground : Light.secondaryBackground
    }

    static func tertiaryBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Dark.tertiaryBackground : Light.tertiaryBackground
    }

    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Dark.primaryText : Light.primaryText
    }

    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Dark.secondaryText : Light.secondaryText
    }

    static func tertiaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Dark.tertiaryText : Light.tertiaryText
    }

    static func accentSoft(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Dark.accentSoft : Light.accentSoft
    }

    static func statusColor(for status: BookStatus) -> Color {
        statusColor(for: status, colorScheme: .light)
    }

    static func statusColor(for status: BookStatus, colorScheme: ColorScheme) -> Color {
        switch status {
        case .reading: return readingAmber
        case .finished: return success
        case .unread: return secondaryText(for: colorScheme)
        case .abandoned: return tertiaryText(for: colorScheme)
        case .planned: return readingAmber
        }
    }
}
#endif
