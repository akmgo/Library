#if os(macOS) || os(iOS)
import SwiftUI

enum AppComponentSizes {
    enum Button {
        static let small: CGFloat = 28
        static let medium: CGFloat = 36
        static let large: CGFloat = 44
        static let hero: CGFloat = 52
    }

    enum Field {
        static let small: CGFloat = 32
        static let medium: CGFloat = 40
        static let large: CGFloat = 48
    }

    enum BookCard {
        static let small: CGFloat = 120
        static let medium: CGFloat = 160
        static let large: CGFloat = 200
        static let extraLarge: CGFloat = 260
        static let coverAspectRatio: CGFloat = 2 / 3
    }

    enum Progress {
        static let linearHeight: CGFloat = 4
        static let linearTrackOpacity: Double = 0.14
        static let ringStroke: CGFloat = 6
        static let ringSizes: [CGFloat] = [72, 96, 120]
    }
}
#endif
