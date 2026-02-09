//
//  TaskMonitorApp.swift
//  TaskMonitor
//
//  View running applications and processes using ports.
//

import SwiftUI

@main
struct TaskMonitorApp: App {
    var body: some Scene {
        WindowGroup {
            TaskMonitorContentView()
                .frame(minWidth: 500, minHeight: 400)
        }
        .defaultSize(width: 560, height: 480)
    }
}
