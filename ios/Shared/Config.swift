//
//  Config.swift
//  Shared
//

import Foundation

enum AppConfig {
    enum HackerNews {
        static let baseURL = "https://hacker-news.firebaseio.com/v0"
        static let itemBatchSize = 30
    }
    enum Reddit {
        static let baseURL = "https://old.reddit.com"
        static let defaultSubreddits = [
            "programming", "technology", "apple",
            "swift", "iosprogramming", "worldnews",
            "science", "askscience"
        ]
    }
}
