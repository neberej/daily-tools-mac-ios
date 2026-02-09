//
//  APIClientApp.swift
//  APIClient
//
//  Postman-like HTTP client: GET, POST, PUT, DELETE with save/load collections.
//

import SwiftUI

@main
struct APIClientApp: App {
    var body: some Scene {
        WindowGroup {
            APIClientContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            StandardMenuCommands()
            CommandMenu("Request") {
                Button("Send Request") {
                    NotificationCenter.default.post(name: .apiClientSendRequest, object: nil)
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .defaultSize(width: 900, height: 650)
    }
}

extension Notification.Name {
    static let apiClientSendRequest = Notification.Name("APIClient.SendRequest")
}
