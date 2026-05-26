#if os(macOS)
import SwiftUI

// MARK: - ✨ 1. 全局动画时间曲线 (Animation)

extension Animation {

    /// Control feedback: buttons, hover states, and compact toggles.
    static var appControlFeedback: Animation {
        .easeOut(duration: 0.16)
    }

    /// Content fade: calm data replacement and small content updates.
    static var appContentFade: Animation {
        .easeInOut(duration: 0.20)
    }

    /// Data change: grid reshaping, progress, charts, and filtered data updates.
    static var appDataChange: Animation {
        .spring(response: 0.32, dampingFraction: 0.9)
    }

    static var appSnappy: Animation { appControlFeedback }
}

#endif
