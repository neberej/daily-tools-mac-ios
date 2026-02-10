//
//  HNItem.swift
//  HackerNews
//

import Foundation

struct HNItem: Codable, Identifiable, Equatable {
    let id: Int
    let type: String?
    let by: String?
    let time: Int?
    let title: String?
    let url: String?
    let text: String?
    let score: Int?
    let descendants: Int?
    let kids: [Int]?
    let parent: Int?
    let deleted: Bool?
    let dead: Bool?

    /// Display-friendly domain extracted from the URL.
    var domain: String? {
        guard let url, let host = URL(string: url)?.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Relative time string.
    var timeAgo: String {
        guard let time else { return "" }
        return TimeAgo.string(from: time)
    }

    /// Whether this is a story (not a comment/job/poll).
    var isStory: Bool {
        type == "story" || type == "job" || type == "poll"
    }

    /// Whether this is a comment.
    var isComment: Bool {
        type == "comment"
    }

    static func == (lhs: HNItem, rhs: HNItem) -> Bool {
        lhs.id == rhs.id
    }
}
