//
//  SubredditMenuView.swift
//  Reddit
//

import SwiftUI

struct SubredditMenuView: View {
    @EnvironmentObject var favorites: FavoriteSubredditsStore
    @State private var showEditSheet = false
    let onSelect: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.surfaceBackground.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 4) {
                        // Front page
                        SubredditButton(name: "Front Page", icon: "house.fill") {
                            onSelect("")
                        }

                        Divider()
                            .background(AppTheme.cardBorder)
                            .padding(.vertical, 8)

                        // Favorite subreddits
                        ForEach(favorites.subreddits, id: \.self) { sub in
                            SubredditButton(name: "r/\(sub)", icon: "star.fill") {
                                onSelect(sub)
                            }
                        }

                        if favorites.subreddits.isEmpty {
                            Text("No favorites yet")
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.secondaryText)
                                .padding(32)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Subreddits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Text("Edit")
                            .foregroundStyle(AppTheme.redditOrange)
                    }
                }
            }
            .toolbarBackground(AppTheme.surfaceBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .sheet(isPresented: $showEditSheet) {
            EditFavoritesView()
                .environmentObject(favorites)
        }
    }
}

// MARK: - Subreddit Button

private struct SubredditButton: View {
    let name: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.redditOrange)
                    .frame(width: 24)

                Text(name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
