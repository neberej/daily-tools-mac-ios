//
//  MenuBarConfiguration.swift
//  Shared
//
//  Shared menu bar structure and commands for MacTools applications.
//

import SwiftUI
import AppKit

// MARK: - Standard menu commands

public struct StandardMenuCommands: Commands {
    public init() {}
    
    public var body: some Commands {
        CommandGroup(replacing: .newItem) { }
        CommandGroup(after: .newItem) {
            Button("New Window") {
                NSApp.sendAction(#selector(NSWindow.makeKeyAndOrderFront(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        CommandGroup(replacing: .undoRedo) { }
        CommandGroup(after: .pasteboard) { }
        CommandGroup(replacing: .saveItem) { }
        
        CommandMenu("View") {
            Button("Toggle Sidebar") {
                NotificationCenter.default.post(name: .toggleSidebar, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
        }
        
        CommandGroup(before: .windowArrangement) {
            Button("Bring All to Front") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.forEach { $0.orderFrontRegardless() }
            }
        }
    }
}

extension Notification.Name {
    public static let toggleSidebar = Notification.Name("MacTools.ToggleSidebar")
}

// MARK: - App-specific menu builder

public struct AppMenuBarBuilder {
    public static func standardEditMenu() -> some Commands {
        CommandGroup(replacing: .pasteboard) {
            Button("Cut") {
                NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("x", modifiers: .command)
            Button("Copy") {
                NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("c", modifiers: .command)
            Button("Paste") {
                NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("v", modifiers: .command)
            Divider()
            Button("Select All") {
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("a", modifiers: .command)
        }
    }
}
