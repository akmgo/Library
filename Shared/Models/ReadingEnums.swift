#if os(macOS) || os(iOS)
import SwiftUI

enum BookStatus: String, Codable, CaseIterable {
    case unread
    case finished
    case reading
    case abandoned
    case planned

    var displayName: String {
        switch self {
        case .unread: return "未读"
        case .finished: return "已读"
        case .reading: return "在读"
        case .abandoned: return "弃读"
        case .planned: return "想读"
        }
    }
}

enum ProgressUnit: String, Codable, CaseIterable {
    case page
    case percent
    case chapter

    var displayName: String {
        switch self {
        case .page: return "页"
        case .percent: return "%"
        case .chapter: return "章"
        }
    }
}

enum ReadingInputMode: String, Codable, CaseIterable {
    case timer
    case manual
}

enum ExcerptCategory: String, Codable, CaseIterable {
    case bookExcerpt
    case note
    case poetry
    case lyric
    case prose
    case quote
    case web
    case movie

    var displayName: String {
        switch self {
        case .bookExcerpt: return "读书摘录"
        case .note: return "笔记"
        case .poetry: return "诗歌"
        case .lyric: return "词曲"
        case .prose: return "短文"
        case .quote: return "语录"
        case .web: return "拾遗"
        case .movie: return "台词"
        }
    }

    static var excerpt: ExcerptCategory { .bookExcerpt }

    var themeColor: Color {
        switch self {
        case .bookExcerpt: return Color(red: 0.78, green: 0.61, blue: 0.35)
        case .note: return .orange
        case .poetry, .lyric: return .orange
        case .prose: return .blue
        case .quote: return .purple
        case .movie: return .pink
        case .web: return .teal
        }
    }
}
#endif
