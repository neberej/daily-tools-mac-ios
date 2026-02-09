//
//  ThemedTextField.swift
//  Shared
//
//  Themed text field and text editor styles.
//

import SwiftUI

public struct ThemedTextFieldStyle: TextFieldStyle {
    public init() {}
    
    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(.system(size: AppTheme.FontSize.body))
            .foregroundColor(AppTheme.primaryText)
            .padding(AppTheme.Spacing.sm)
            .background(AppTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}

public struct ThemedTextEditorStyle: ViewModifier {
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .font(.system(size: AppTheme.FontSize.body))
            .foregroundColor(AppTheme.primaryText)
            .scrollContentBackground(.hidden)
            .padding(AppTheme.Spacing.sm)
            .background(AppTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}

public extension View {
    func themedTextEditor() -> some View {
        modifier(ThemedTextEditorStyle())
    }
}
