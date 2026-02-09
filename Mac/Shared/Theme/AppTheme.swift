//
//  AppTheme.swift
//  Shared
//
//  Central color scheme and visual constants for all MacTools applications.
//

import SwiftUI
import AppKit

// MARK: - Color Palette

public enum AppTheme {
    
    // Primary palette — used for key actions and focus
    public static let primary = Color(nsColor: .controlAccentColor)
    public static let primaryHover = Color(nsColor: .controlAccentColor).opacity(0.85)
    
    // Background hierarchy
    public static let background = Color(nsColor: .windowBackgroundColor)
    public static let secondaryBackground = Color(nsColor: .controlBackgroundColor)
    public static let tertiaryBackground = Color(nsColor: .textBackgroundColor)
    
    // Content
    public static let primaryText = Color(nsColor: .labelColor)
    public static let secondaryText = Color(nsColor: .secondaryLabelColor)
    public static let tertiaryText = Color(nsColor: .tertiaryLabelColor)
    
    // Semantic
    public static let success = Color(red: 0.2, green: 0.68, blue: 0.35)
    public static let warning = Color(red: 0.95, green: 0.6, blue: 0.2)
    public static let error = Color(red: 0.9, green: 0.25, blue: 0.25)
    public static let info = Color(red: 0.25, green: 0.5, blue: 0.95)
    
    // Borders and dividers
    public static let border = Color(nsColor: .separatorColor)
    public static let borderLight = Color(nsColor: .separatorColor).opacity(0.6)
    
    // Spacing scale (8pt grid)
    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }
    
    // Corner radius
    public enum Radius {
        public static let sm: CGFloat = 4
        public static let md: CGFloat = 6
        public static let lg: CGFloat = 8
        public static let xl: CGFloat = 12
    }
    
    // Typography (relative to system)
    public enum FontSize {
        public static let caption: CGFloat = 11
        public static let body: CGFloat = 13
        public static let bodyLarge: CGFloat = 15
        public static let subheadline: CGFloat = 12
        public static let headline: CGFloat = 17
        public static let title: CGFloat = 20
        public static let largeTitle: CGFloat = 26
    }
}

// MARK: - View Modifiers for consistent styling

public struct ThemedBackgroundModifier: ViewModifier {
    let level: BackgroundLevel
    
    public enum BackgroundLevel {
        case primary
        case secondary
        case tertiary
    }
    
    public func body(content: Content) -> some View {
        content
            .background(backgroundColor)
    }
    
    private var backgroundColor: Color {
        switch level {
        case .primary: return AppTheme.background
        case .secondary: return AppTheme.secondaryBackground
        case .tertiary: return AppTheme.tertiaryBackground
        }
    }
}

public extension View {
    func themedBackground(_ level: ThemedBackgroundModifier.BackgroundLevel = .primary) -> some View {
        modifier(ThemedBackgroundModifier(level: level))
    }
}
