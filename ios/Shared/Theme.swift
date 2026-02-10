//
//  Theme.swift
//  Shared
//

import SwiftUI

enum AppTheme {
    // MARK: - Colors
    static let hnOrange = Color(red: 1.0, green: 0.4, blue: 0.0)
    static let redditOrange = Color(red: 1.0, green: 0.27, blue: 0.0)

    static let cardBackground = Color.white.opacity(0.06)
    static let cardBorder = Color.white.opacity(0.1)
    static let surfaceBackground = Color(red: 0.06, green: 0.06, blue: 0.08)
    static let secondaryText = Color.white.opacity(0.5)
    static let tertiaryText = Color.white.opacity(0.35)

    // MARK: - Depth colors for comment nesting
    static let depthColors: [Color] = [
        Color(red: 1.0, green: 0.4, blue: 0.0),   // orange
        Color(red: 0.3, green: 0.6, blue: 1.0),   // blue
        Color(red: 0.3, green: 0.85, blue: 0.5),  // green
        Color(red: 0.7, green: 0.4, blue: 1.0),   // purple
        Color(red: 1.0, green: 0.75, blue: 0.2),  // gold
        Color(red: 1.0, green: 0.4, blue: 0.6),   // pink
    ]

    static func depthColor(for depth: Int) -> Color {
        depthColors[depth % depthColors.count]
    }

    // MARK: - Fonts
    static let titleFont = Font.system(size: 16, weight: .semibold, design: .default)
    static let bodyFont = Font.system(size: 15, weight: .regular, design: .default)
    static let captionFont = Font.system(size: 13, weight: .regular, design: .default)
    static let smallCaptionFont = Font.system(size: 11, weight: .medium, design: .rounded)

    // MARK: - Card Style Modifier
    static let cardCornerRadius: CGFloat = 14
    static let cardPadding: CGFloat = 12
}

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.cardPadding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.cardBorder, lineWidth: 0.5)
            )
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
}
