//
//  ToolbarStyle.swift
//  Shared
//
//  Shared toolbar and window chrome styling.
//

import SwiftUI
import AppKit

// MARK: - Toolbar background

public struct ThemedToolbarBackground: View {
    public init() {}
    
    public var body: some View {
        Rectangle()
            .fill(AppTheme.secondaryBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(AppTheme.border)
                , alignment: .bottom
            )
    }
}

// MARK: - Toolbar item group

public struct ThemedToolbarGroup<Content: View>: View {
    let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            content
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.xs)
    }
}

// MARK: - Section header (sidebar / inspector)

public struct ThemedSectionHeader: View {
    let title: String
    
    public init(_ title: String) {
        self.title = title
    }
    
    public var body: some View {
        Text(title)
            .font(.system(size: AppTheme.FontSize.caption, weight: .semibold))
            .foregroundColor(AppTheme.secondaryText)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Divider

public struct ThemedDivider: View {
    public init() {}
    
    public var body: some View {
        Rectangle()
            .fill(AppTheme.border)
            .frame(height: 1)
    }
}

// MARK: - Toolbar icon button with hover effect

public struct ToolbarIconButton: View {
    let systemName: String
    let action: () -> Void
    let helpText: String
    @State private var isHovering = false

    public init(systemName: String, help: String, action: @escaping () -> Void) {
        self.systemName = systemName
        self.helpText = help
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16))
                .foregroundColor(isHovering ? AppTheme.primary : AppTheme.secondaryText)
                .scaleEffect(isHovering ? 1.08 : 1)
                .animation(.easeInOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Bottom toolbar (consistent across all MacTools apps)

public struct AppBottomToolbar<Trailing: View>: View {
    var newAction: (() -> Void)?
    var saveCurrentAction: (() -> Void)?
    var openAction: (() -> Void)?
    var saveAction: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing

    public init(
        new: (() -> Void)? = nil,
        saveCurrent: (() -> Void)? = nil,
        open: (() -> Void)? = nil,
        save: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.newAction = new
        self.saveCurrentAction = saveCurrent
        self.openAction = open
        self.saveAction = save
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            if let newAction = newAction {
                ToolbarIconButton(systemName: "doc", help: "New", action: newAction)
            }
            if let saveCurrentAction = saveCurrentAction {
                ToolbarIconButton(systemName: "externaldrive", help: "Save request", action: saveCurrentAction)
            }
            if let openAction = openAction {
                ToolbarIconButton(systemName: "folder", help: "Open", action: openAction)
            }
            if let saveAction = saveAction {
                ToolbarIconButton(systemName: "square.and.arrow.down", help: "Save", action: saveAction)
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(
            Rectangle()
                .fill(AppTheme.secondaryBackground)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(AppTheme.border),
                    alignment: .top
                )
        )
    }
}

public extension AppBottomToolbar where Trailing == EmptyView {
    init(
        new: (() -> Void)? = nil,
        saveCurrent: (() -> Void)? = nil,
        open: (() -> Void)? = nil,
        save: (() -> Void)? = nil
    ) {
        self.newAction = new
        self.saveCurrentAction = saveCurrent
        self.openAction = open
        self.saveAction = save
        self.trailing = { EmptyView() }
    }
}
