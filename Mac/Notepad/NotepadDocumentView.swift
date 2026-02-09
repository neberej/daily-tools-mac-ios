//
//  NotepadDocumentView.swift
//  Notepad
//
//  Document-based notepad. Title, save prompts, and window creation are managed by SwiftUI + AppKit.
//

import SwiftUI
import AppKit

struct NotepadDocumentView: View {
    @Binding var document: NotepadDocument

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $document.text)
                .font(.system(size: AppTheme.FontSize.body))
                .foregroundColor(AppTheme.primaryText)
                .scrollContentBackground(.hidden)
                .background(AppTheme.tertiaryBackground)
                .padding(AppTheme.Spacing.md)
            bottomToolbar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themedBackground(.primary)
    }

    private var bottomToolbar: some View {
        AppBottomToolbar(
            new: {
                NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)),
                                 to: nil,
                                 from: nil)
            },
            open: {
                NSApp.sendAction(#selector(NSDocumentController.openDocument(_:)),
                                 to: nil,
                                 from: nil)
            },
            save: {
                NSApp.sendAction(#selector(NSDocument.save(_:)),
                                 to: nil,
                                 from: nil)
            },
            trailing: { EmptyView() }
        )
    }

}
