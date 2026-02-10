//
//  TimeAgo.swift
//  Shared
//

import Foundation

enum TimeAgo {
    /// Converts a Unix timestamp to a relative time string like "2h ago".
    static func string(from unixTime: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(unixTime))
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days < 30 { return "\(days)d ago" }
        let months = days / 30
        if months < 12 { return "\(months)mo ago" }
        let years = months / 12
        return "\(years)y ago"
    }
}
