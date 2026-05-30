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
        case .bookExcerpt: return "书摘"
        case .note: return "笔记"
        case .poetry: return "诗歌"
        case .lyric: return "词曲"
        case .prose: return "短文"
        case .quote: return "语录"
        case .web: return "拾遗"
        case .movie: return "台词"
        }
    }
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

enum BookExcerptFilter: String, CaseIterable {
    case all
    case excerpts
    case notes

    var displayName: String {
        switch self {
        case .all: return "全部"
        case .excerpts: return "摘录"
        case .notes: return "笔记"
        }
    }

    func includes(_ excerpt: Excerpt) -> Bool {
        switch self {
        case .all:
            return true
        case .excerpts:
            return excerpt.type == .bookExcerpt
        case .notes:
            return excerpt.type == .note
        }
    }

    func count(in excerpts: [Excerpt]) -> Int {
        excerpts.filter { includes($0) }.count
    }
}

enum BookContentEntryMode: Hashable, CaseIterable {
    case excerpt
    case note

    var displayName: String {
        switch self {
        case .excerpt: return "摘录"
        case .note: return "笔记"
        }
    }

    var contentLabel: String {
        switch self {
        case .excerpt: return "摘录正文"
        case .note: return "笔记正文"
        }
    }

    var iconName: String {
        switch self {
        case .excerpt: return "text.quote"
        case .note: return "note.text"
        }
    }

    var tint: Color {
        switch self {
        case .excerpt: return Color(red: 200 / 255, green: 155 / 255, blue: 90 / 255)
        case .note: return Color(red: 214 / 255, green: 160 / 255, blue: 79 / 255)
        }
    }

    var category: ExcerptCategory {
        switch self {
        case .excerpt: return .bookExcerpt
        case .note: return .note
        }
    }

    var placeholder: String {
        switch self {
        case .excerpt: return "输入书中值得留下的句子..."
        case .note: return "记录此刻的想法..."
        }
    }

    var saveTitle: String {
        switch self {
        case .excerpt: return "保存摘录"
        case .note: return "保存笔记"
        }
    }
}
#endif
