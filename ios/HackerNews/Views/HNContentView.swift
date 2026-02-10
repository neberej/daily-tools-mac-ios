//
//  HNContentView.swift
//  HackerNews
//

import SwiftUI

struct HNContentView: View {
    @EnvironmentObject var service: HNService
    @State private var selectedFeed: HNFeed = .top

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.surfaceBackground.ignoresSafeArea()

            FeedView(feed: selectedFeed)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating glass tab bar
            GlassBar {
                ForEach(HNFeed.allCases) { feed in
                    GlassTabButton(
                        title: feed.rawValue,
                        isSelected: selectedFeed == feed
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFeed = feed
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
