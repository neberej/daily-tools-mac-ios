//
//  RedditContentView.swift
//  Reddit
//

import SwiftUI

// MARK: - Sort types

private enum RedditSort: String, CaseIterable {
    case hot, new, top
    var label: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .hot: return "flame"
        case .new: return "clock"
        case .top: return "arrow.up"
        }
    }

    /// The query value reddit uses for comment sorting
    var commentSortValue: String {
        switch self {
        case .hot: return "confidence"
        case .new: return "new"
        case .top: return "top"
        }
    }
}

private enum TopTimePeriod: String, CaseIterable {
    case hour, day, week, month, year, all
    var label: String { rawValue.capitalized }
}

// MARK: - View

struct RedditContentView: View {
    @EnvironmentObject var favorites: FavoriteSubredditsStore
    @State private var currentSubreddit: String = ""
    @State private var currentURL: URL
    @State private var navigationID = UUID()
    @State private var showSubredditMenu = false
    @State private var navigationTitle = "Reddit"
    @State private var currentSort: RedditSort = .hot
    @State private var topTimePeriod: TopTimePeriod = .day
    @State private var showTopPicker = false
    @State private var liveWebURL: URL?  // tracks what the web view is actually showing

    private var isOnCommentPage: Bool {
        guard let url = liveWebURL else { return false }
        return url.path.contains("/comments/")
    }

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
                },
                onURLChange: { url in
                    liveWebURL = url
                }
            )
            .ignoresSafeArea(edges: .bottom)

            // Top bar — single row
            HStack(spacing: 8) {
                // Subreddit pill
                Button {
                    showSubredditMenu = true
                } label: {
                    HStack(spacing: 5) {
                        Text(navigationTitle)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)

                // Sort pills
                ForEach(RedditSort.allCases, id: \.self) { sort in
                    Button {
                        if sort == .top && !isOnCommentPage {
                            if currentSort == .top {
                                showTopPicker = true
                            } else {
                                currentSort = .top
                                applySort()
                            }
                        } else {
                            currentSort = sort
                            applySort()
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: sort.icon)
                                .font(.system(size: 10, weight: .semibold))
                            Text(sortLabel(for: sort))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .foregroundStyle(currentSort == sort ? .white : .white.opacity(0.55))
                        .background(
                            currentSort == sort
                                ? AnyShapeStyle(AppTheme.redditOrange.opacity(0.25))
                                : AnyShapeStyle(.ultraThinMaterial),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                currentSort == sort
                                    ? AppTheme.redditOrange.opacity(0.4)
                                    : .white.opacity(0.1),
                                lineWidth: 0.5
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Home button
                Button {
                    currentSort = .hot
                    navigateTo(subreddit: "")
                } label: {
                    Image(systemName: "house")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
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
        .confirmationDialog("Top posts from", isPresented: $showTopPicker) {
            ForEach(TopTimePeriod.allCases, id: \.self) { period in
                Button(period.label) {
                    topTimePeriod = period
                    applySort()
                }
            }
        }
    }

    // MARK: - Helpers

    private func sortLabel(for sort: RedditSort) -> String {
        if sort == .top && currentSort == .top && !isOnCommentPage {
            return topTimePeriod.label
        }
        return sort.label
    }

    // MARK: - Navigation

    private func navigateTo(subreddit: String) {
        currentSubreddit = subreddit
        buildListingURL()
    }

    private func applySort() {
        if let live = liveWebURL, live.path.contains("/comments/") {
            // Comment page: use ?sort=confidence/new/top (no time period)
            var components = URLComponents(url: live, resolvingAgainstBaseURL: false)!
            var items = (components.queryItems ?? []).filter { $0.name != "sort" && $0.name != "t" }
            items.append(URLQueryItem(name: "sort", value: currentSort.commentSortValue))
            components.queryItems = items.isEmpty ? nil : items
            currentURL = components.url!
            navigationID = UUID()
        } else {
            buildListingURL()
        }
    }

    private func buildListingURL() {
        let base = AppConfig.Reddit.baseURL
        var path: String

        // Hot is the default — no sort param needed
        if currentSort == .hot {
            if currentSubreddit.isEmpty {
                path = base
            } else {
                path = "\(base)/r/\(currentSubreddit)"
            }
        } else {
            if currentSubreddit.isEmpty {
                path = "\(base)/\(currentSort.rawValue)"
            } else {
                path = "\(base)/r/\(currentSubreddit)/\(currentSort.rawValue)"
            }
        }

        if currentSort == .top {
            path += "?t=\(topTimePeriod.rawValue)"
        }

        currentURL = URL(string: path)!
        navigationID = UUID()
    }
}
