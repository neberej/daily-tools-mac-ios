//
//  RedditContentView.swift
//  Reddit
//

import SwiftUI

struct RedditContentView: View {
    @EnvironmentObject var favorites: FavoriteSubredditsStore
    @State private var currentSubreddit: String = ""
    @State private var currentURL: URL
    @State private var navigationID = UUID()
    @State private var showSubredditMenu = false
    @State private var navigationTitle = "Reddit"

    init() {
        _currentSubreddit = State(initialValue: "")
        _currentURL = State(initialValue: URL(string: AppConfig.Reddit.baseURL)!)
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.surfaceBackground.ignoresSafeArea()

            RedditWebView(
                url: currentURL,
                navigationID: navigationID,
                onNavigationTitle: { title in
                    navigationTitle = title
                }
            )
            .ignoresSafeArea(edges: .bottom)

            // Top bar overlay
            HStack {
                // Current subreddit pill
                Button {
                    showSubredditMenu = true
                } label: {
                    HStack(spacing: 6) {
                        Text(navigationTitle)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                // Home button
                Button {
                    navigateTo(subreddit: "")
                } label: {
                    Image(systemName: "house")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showSubredditMenu) {
            SubredditMenuView(
                onSelect: { subreddit in
                    navigateTo(subreddit: subreddit)
                    showSubredditMenu = false
                }
            )
            .environmentObject(favorites)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func navigateTo(subreddit: String) {
        currentSubreddit = subreddit
        if subreddit.isEmpty {
            currentURL = URL(string: AppConfig.Reddit.baseURL)!
        } else {
            currentURL = URL(string: "\(AppConfig.Reddit.baseURL)/r/\(subreddit)")!
        }
        navigationID = UUID()  // always force a new load
    }
}
