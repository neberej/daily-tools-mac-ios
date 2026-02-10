//
//  EditFavoritesView.swift
//  Reddit
//

import SwiftUI

struct EditFavoritesView: View {
    @EnvironmentObject var favorites: FavoriteSubredditsStore
    @Environment(\.dismiss) private var dismiss
    @State private var newSubreddit = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.surfaceBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Add new subreddit field
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.redditOrange)

                        TextField("Add subreddit...", text: $newSubreddit)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($isFieldFocused)
                            .onSubmit {
                                addSubreddit()
                            }

                        if !newSubreddit.isEmpty {
                            Button("Add") {
                                addSubreddit()
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.redditOrange)
                        }
                    }
                    .padding(16)
                    .background(AppTheme.cardBackground)

                    Divider().background(AppTheme.cardBorder)

                    // List of favorites
                    List {
                        ForEach(favorites.subreddits, id: \.self) { sub in
                            HStack {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.redditOrange)

                                Text("r/\(sub)")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                            }
                            .listRowBackground(AppTheme.surfaceBackground)
                        }
                        .onDelete { offsets in
                            favorites.remove(at: offsets)
                        }
                        .onMove { source, dest in
                            favorites.move(from: source, to: dest)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Edit Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.redditOrange)
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .foregroundStyle(AppTheme.redditOrange)
                }
            }
            .toolbarBackground(AppTheme.surfaceBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func addSubreddit() {
        favorites.add(newSubreddit)
        newSubreddit = ""
        isFieldFocused = false
    }
}
