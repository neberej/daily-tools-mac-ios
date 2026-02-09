//
//  ImageViewerApp.swift
//  ImageViewer
//
//  Preview-like image viewer: open, zoom, pan, multiple windows.
//

import SwiftUI

@main
struct ImageViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ImageViewerContentView()
                .frame(minWidth: 400, minHeight: 300)
        }
        .commands {
            StandardMenuCommands()
            CommandGroup(after: .newItem) {
                Button("Open Image…") {
                    NotificationCenter.default.post(name: .imageViewerOpen, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
        .defaultSize(width: 800, height: 600)
    }
}

extension Notification.Name {
    static let imageViewerOpen = Notification.Name("ImageViewer.Open")
}
