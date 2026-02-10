//
//  FeedView.swift
//  HackerNews
//

import SwiftUI

struct FeedView: View {
    let feed: HNFeed
    @EnvironmentObject var service: HNService

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(service.stories.enumerated()), id: \.element.id) { index, story in
                    StoryRowView(story: story, rank: index + 1)
                        .onAppear {
                            // Load more when near the end
                            if index == service.stories.count - 5 {
                                Task { await service.loadMore() }
                            }
                        }
                }

                if service.isLoading {
                    ProgressView()
                        .tint(AppTheme.hnOrange)
                        .padding(40)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 12)
            .padding(.bottom, 120) // space for glass bar
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await service.loadFeed(feed)
        }
        .task(id: feed) {
            await service.loadFeed(feed)
        }
    }
}
