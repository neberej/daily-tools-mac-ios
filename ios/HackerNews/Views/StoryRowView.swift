//
//  StoryRowView.swift
//  HackerNews
//

import SwiftUI

struct StoryRowView: View {
    let story: HNItem
    let rank: Int

    @State private var showSafari = false
    @State private var showComments = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title row
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(rank)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.hnOrange)
                    .frame(width: 18, alignment: .trailing)

                VStack(alignment: .leading, spacing: 3) {
                    Text(story.title ?? "Untitled")
                        .font(AppTheme.titleFont)
                        .foregroundStyle(.white)
                        .lineLimit(3)

                    if let domain = story.domain {
                        Text(domain)
                            .font(AppTheme.smallCaptionFont)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }

            // Meta row
            HStack(spacing: 10) {
                Label("\(story.score ?? 0)", systemImage: "arrow.up")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.hnOrange)

                Label(story.by ?? "anon", systemImage: "person")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)

                Text(story.timeAgo)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.tertiaryText)

                Spacer()

                // Comments button
                Button {
                    showComments = true
                } label: {
                    Label("\(story.descendants ?? 0)", systemImage: "bubble.right")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 24)
        }
        .glassCard()
        .contentShape(Rectangle())
        .onTapGesture {
            if story.url != nil {
                showSafari = true
            } else {
                showComments = true
            }
        }
        .fullScreenCover(isPresented: $showSafari) {
            if let urlString = story.url, let url = URL(string: urlString) {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showComments) {
            CommentsView(story: story)
        }
    }
}
