//
//  CommentsView.swift
//  HackerNews
//

import SwiftUI

struct CommentsView: View {
    let story: HNItem
    @EnvironmentObject var service: HNService
    @Environment(\.dismiss) private var dismiss

    @State private var comments: [CommentNode] = []
    @State private var isLoading = true
    @State private var showSafari = false
    @State private var collapsedIDs: Set<Int> = []

    // Track top-level comment IDs for "next comment" navigation
    @State private var topLevelIDs: [Int] = []
    @State private var currentTopLevelIndex = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppTheme.surfaceBackground.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            // Story header
                            storyHeader
                                .id("header")

                            if isLoading {
                                ProgressView()
                                    .tint(AppTheme.hnOrange)
                                    .frame(maxWidth: .infinity)
                                    .padding(60)
                            } else if comments.isEmpty {
                                Text("No comments yet")
                                    .font(AppTheme.bodyFont)
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(60)
                            } else {
                                let flat = flattenedComments()
                                ForEach(Array(flat.enumerated()), id: \.element.node.id) { _, entry in
                                    CommentRowView(
                                        node: entry.node,
                                        depth: entry.depth,
                                        isCollapsed: collapsedIDs.contains(entry.node.id),
                                        onToggle: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                if collapsedIDs.contains(entry.node.id) {
                                                    collapsedIDs.remove(entry.node.id)
                                                } else {
                                                    collapsedIDs.insert(entry.node.id)
                                                }
                                            }
                                        }
                                    )
                                    .id(entry.node.id)
                                }
                            }
                        }
                        .padding(.bottom, 120)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: currentTopLevelIndex) { _, newIdx in
                        guard newIdx < topLevelIDs.count else { return }
                        withAnimation {
                            proxy.scrollTo(topLevelIDs[newIdx], anchor: .top)
                        }
                    }
                }

                // Floating "next top-level comment" button
                if !comments.isEmpty {
                    FloatingActionButton(systemImage: "chevron.down") {
                        let next = currentTopLevelIndex + 1
                        currentTopLevelIndex = next < topLevelIDs.count ? next : 0
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppTheme.hnOrange)
                }
            }
            .toolbarBackground(AppTheme.surfaceBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .task {
            let ids = story.kids ?? []
            let tree = await service.fetchCommentTree(ids: ids)
            comments = tree
            topLevelIDs = tree.map { $0.id }
            isLoading = false
        }
    }

    // MARK: - Story Header

    private var storyHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(story.title ?? "")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                Label("\(story.score ?? 0)", systemImage: "arrow.up")
                    .foregroundStyle(AppTheme.hnOrange)
                Label(story.by ?? "", systemImage: "person")
                    .foregroundStyle(AppTheme.secondaryText)
                Text(story.timeAgo)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .font(AppTheme.captionFont)

            if let urlString = story.url, let url = URL(string: urlString) {
                Button {
                    showSafari = true
                } label: {
                    Label(story.domain ?? "Link", systemImage: "link")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.hnOrange)
                }
                .buttonStyle(.plain)
                .fullScreenCover(isPresented: $showSafari) {
                    SafariView(url: url).ignoresSafeArea()
                }
            }

            if let text = story.text {
                Text(HTMLRenderer.render(text))
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
    }

    // MARK: - Comment Tree (flattened to avoid recursive opaque return type)

    /// Flattens the tree into a list of (node, depth) pairs, respecting collapsed state.
    private func flattenedComments() -> [(node: CommentNode, depth: Int)] {
        var result: [(node: CommentNode, depth: Int)] = []
        func walk(_ nodes: [CommentNode], depth: Int) {
            for node in nodes {
                result.append((node, depth))
                if !collapsedIDs.contains(node.id) {
                    walk(node.children, depth: depth + 1)
                }
            }
        }
        walk(comments, depth: 0)
        return result
    }
}
