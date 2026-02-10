//
//  RedditApp.swift
//  Reddit
//

import SwiftUI

@main
struct RedditApp: App {
    @StateObject private var favorites = FavoriteSubredditsStore()

    var body: some Scene {
        WindowGroup {
            RedditContentView()
                .environmentObject(favorites)
                .preferredColorScheme(.dark)
        }
    }
}
