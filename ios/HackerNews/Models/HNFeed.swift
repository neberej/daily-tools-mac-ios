//
//  HNFeed.swift
//  HackerNews
//

import Foundation

enum HNFeed: String, CaseIterable, Identifiable {
    case top = "Top"
    case new = "New"
    case show = "Show"
    case ask = "Ask"

    var id: String { rawValue }

    /// API endpoint path for fetching story IDs.
    var endpoint: String {
        switch self {
        case .top:  return "topstories"
        case .new:  return "newstories"
        case .show: return "showstories"
        case .ask:  return "askstories"
        }
    }
}
