//
//  DropdownMenu.swift
//  Shared
//
//  Reusable dropdown / picker components with shared styling.
//

import SwiftUI
import AppKit

// MARK: - Dropdown Menu (native NSPopUpButton style)

public struct ThemedDropdown<Item: Hashable>: View {
    @Binding var selection: Item
    let items: [Item]
    let label: (Item) -> String
    var placeholder: String? = nil
    
    public init(
        selection: Binding<Item>,
        items: [Item],
        label: @escaping (Item) -> String,
        placeholder: String? = nil
    ) {
        self._selection = selection
        self.items = items
        self.label = label
        self.placeholder = placeholder
    }
    
    public var body: some View {
        Menu {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Button(label(item)) {
                    selection = item
                }
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.xs) {
                Text(selectionIndex.map { label(items[$0]) } ?? (placeholder ?? "Select"))
                    .foregroundColor(AppTheme.primaryText)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppTheme.secondaryText)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .frame(minWidth: 80, alignment: .leading)
            .background(AppTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: true, vertical: true)
    }
    
    private var selectionIndex: Int? {
        items.firstIndex(where: { $0 == selection })
    }
}

// MARK: - Segmented Picker (for method / view mode toggles)

public struct ThemedSegmentedPicker<Item: Hashable>: View {
    @Binding var selection: Item
    let items: [Item]
    let label: (Item) -> String
    
    public init(selection: Binding<Item>, items: [Item], label: @escaping (Item) -> String) {
        self._selection = selection
        self.items = items
        self.label = label
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let isSelected = item == selection
                Button {
                    selection = item
                } label: {
                    Text(label(item))
                        .font(.system(size: AppTheme.FontSize.subheadline, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: index == 0 ? AppTheme.Radius.sm : 0)
                        .fill(isSelected ? AppTheme.tertiaryBackground : Color.clear)
                )
                .overlay(
                    Group {
                        if index == 0 {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                                .stroke(AppTheme.border, lineWidth: 1)
                                .mask(
                                    Rectangle()
                                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: -1))
                                )
                        }
                    }
                )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - Context menu helper (use .contextMenu { ... } with ViewBuilder menu items directly)
