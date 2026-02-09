//
//  NotepadApp.swift
//  Notepad
//
//  Multi-window notepad. All windows managed by SwiftUI DocumentGroup.
//

import SwiftUI

@main
struct NotepadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        DocumentGroup(newDocument: NotepadDocument()) { config in
            NotepadDocumentView(document: config.$document)
        }

        Settings {
            NotepadSettingsView()
        }
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Only create a document if none were restored/opened
        if NSDocumentController.shared.documents.isEmpty {
            NSApp.sendAction(
                #selector(NSDocumentController.newDocument(_:)),
                to: nil,
                from: nil
            )
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
