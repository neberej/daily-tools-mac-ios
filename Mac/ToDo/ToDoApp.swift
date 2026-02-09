//
//  ToDoApp.swift
//  ToDo
//
//  Calendar-scoped todo list with period filters.
//

import SwiftUI

@main
struct ToDoApp: App {
    var body: some Scene {
        WindowGroup {
            ToDoContentView()
                .frame(minWidth: 420, minHeight: 420)
        }
        .defaultSize(width: 480, height: 520)
    }
}
