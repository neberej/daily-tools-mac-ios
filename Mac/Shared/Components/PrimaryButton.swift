//
//  PrimaryButton.swift
//  Shared
//
//  Primary and secondary button styles used across MacTools apps.
//

import SwiftUI

// MARK: - Primary Button Style

public struct PrimaryButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    
    public init(isDestructive: Bool = false) {
        self.isDestructive = isDestructive
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: AppTheme.FontSize.body, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                    .fill(backgroundColor(configuration: configuration))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
    
    private func backgroundColor(configuration: Configuration) -> Color {
        let base = isDestructive ? AppTheme.error : AppTheme.primary
        return configuration.isPressed ? base.opacity(0.8) : base
    }
}

// MARK: - Secondary Button Style

public struct SecondaryButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: AppTheme.FontSize.body, weight: .medium))
            .foregroundColor(AppTheme.primaryText)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                    .stroke(AppTheme.border, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                            .fill(configuration.isPressed ? AppTheme.tertiaryBackground : AppTheme.secondaryBackground)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Bordered Prominent (toolbar-style)

public struct BorderedProminentButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: AppTheme.FontSize.subheadline, weight: .medium))
            .foregroundColor(configuration.isPressed ? AppTheme.primary.opacity(0.8) : AppTheme.primary)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                    .fill(AppTheme.primary.opacity(configuration.isPressed ? 0.15 : 0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                    .stroke(AppTheme.primary.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Convenience extensions

public extension View {
    func primaryButtonStyle(isDestructive: Bool = false) -> some View {
        buttonStyle(PrimaryButtonStyle(isDestructive: isDestructive))
    }
    
    func secondaryButtonStyle() -> some View {
        buttonStyle(SecondaryButtonStyle())
    }
    
    func borderedProminentButtonStyle() -> some View {
        buttonStyle(BorderedProminentButtonStyle())
    }
}
