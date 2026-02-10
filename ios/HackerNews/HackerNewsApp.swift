//
//  HackerNewsApp.swift
//  HackerNews
//

import SwiftUI

@main
struct HackerNewsApp: App {
    @StateObject private var service = HNService()

    var body: some Scene {
        WindowGroup {
            HNContentView()
                .environmentObject(service)
                .preferredColorScheme(.dark)
        }
    }
}
