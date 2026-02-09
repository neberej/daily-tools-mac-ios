//
//  PaintApp.swift
//  Paint
//
//  Classic Paint-style drawing: tools, canvas, color palette. Uses shared UI/style.
//

import SwiftUI

@main
struct PaintApp: App {
    var body: some Scene {
        WindowGroup {
            PaintContentView()
                .frame(minWidth: 600, minHeight: 500)
        }
        .commands {
            StandardMenuCommands()
            CommandGroup(replacing: .newItem) {
                Button("New") {
                    NotificationCenter.default.post(name: .paintNew, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu("Edit") {
                Button("Undo") {
                    NotificationCenter.default.post(name: .paintUndo, object: nil)
                }
                .keyboardShortcut("z", modifiers: .command)
                Button("Clear Image") {
                    NotificationCenter.default.post(name: .paintClear, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandMenu("View") {
                // Zoom, grid, etc. can be added
            }
            CommandMenu("Image") {
                // Resize, rotate, etc. can be added
            }
            CommandMenu("Colors") {
                // Edit colors can be added
            }
            CommandMenu("Help") {
                Button("About Paint") {}
            }
        }
        .defaultSize(width: 900, height: 700)
    }
}
