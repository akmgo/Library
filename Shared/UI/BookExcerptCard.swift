#if os(macOS) || os(iOS)
import SwiftUI

/// Shared excerpt/note card wrapping BookExcerptCardContent in an AppCard.
/// Used by iOS and macOS book detail views.
struct BookExcerptCard: View {
    let item: ReadingStatsCalculator.BookExcerptItemSnapshot
    var contentFontSize: CGFloat = 15

    var body: some View {
        AppCard {
            BookExcerptCardContent(item: item, contentFontSize: contentFontSize)
        }
    }
}
#endif
