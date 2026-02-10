//
//  CommentRowView.swift
//  HackerNews
//

import SwiftUI

struct CommentRowView: View {
    let node: CommentNode
    let depth: Int
    let isCollapsed: Bool
    let onToggle: () -> Void

    private var item: HNItem { node.item }
    private let maxIndent = 6

    var body: some View {
        HStack(spacing: 0) {
            // Depth indicator bars
            if depth > 0 {
                ForEach(0..<min(depth, maxIndent), id: \.self) { d in
                    Rectangle()
                        .fill(AppTheme.depthColor(for: d))
                        .frame(width: 2)
                        .padding(.trailing, d == min(depth, maxIndent) - 1 ? 10 : 6)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                // Author + time + collapse indicator
                HStack(spacing: 8) {
                    Text(item.by ?? "[deleted]")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.depthColor(for: depth))

                    Text(item.timeAgo)
                        .font(AppTheme.smallCaptionFont)
                        .foregroundStyle(AppTheme.tertiaryText)

                    Spacer()

                    if !node.children.isEmpty {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                }

                // Comment body
                if !isCollapsed, let text = item.text {
                    Text(HTMLRenderer.render(text))
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(.white.opacity(0.85))
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .padding(.leading, depth > 0 ? CGFloat(min(depth, maxIndent)) * 4 : 0)
        .background(
            depth == 0
                ? AppTheme.cardBackground
                : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }

        // Separator for top-level comments
        if depth == 0 {
            Divider()
                .background(AppTheme.cardBorder)
        }
    }
}
