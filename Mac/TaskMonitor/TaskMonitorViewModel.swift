//
//  TaskMonitorViewModel.swift
//  TaskMonitor
//

import SwiftUI
import AppKit
import Darwin

// MARK: - Row models (value types, SwiftUI-friendly identity)

struct AppProcess: Identifiable, Equatable {
    let id: pid_t
    let name: String
    let icon: NSImage?
    let bundleIdentifier: String?

    static func == (lhs: AppProcess, rhs: AppProcess) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}

struct PortEntry: Identifiable, Hashable {
    var id: String { "\(pid)-\(port)" }
    let port: Int
    let processName: String
    let pid: Int32
}

// MARK: - View model

@MainActor
final class TaskMonitorViewModel: ObservableObject {
    @Published var applications: [AppProcess] = []
    @Published var filterSystemApps = false
    @Published var portEntries: [PortEntry] = []
    @Published var isRefreshingPorts = false

    var displayedApplications: [AppProcess] {
        if filterSystemApps {
            return applications.filter { app in
                guard let bundleId = app.bundleIdentifier else { return true }
                if bundleId.hasPrefix("com.apple.") { return false }
                return true
            }
        }
        return applications
    }

    func refresh(for tab: TaskMonitorTab) {
        switch tab {
        case .applications:
            refreshApplications()
        case .port:
            refreshPorts()
        }
    }

    /// Refreshes both Applications and Port tabs in one go.
    func refreshAll() {
        refreshApplications()
        refreshPorts()
    }

    func refreshApplications() {
        applications = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map {
                AppProcess(
                    id: $0.processIdentifier,
                    name: $0.localizedName ?? $0.bundleIdentifier ?? "Unknown",
                    icon: $0.icon,
                    bundleIdentifier: $0.bundleIdentifier
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func terminate(_ app: AppProcess) {
        guard let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == app.id }) else { return }
        runningApp.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refreshApplications()
        }
    }

    func refreshPorts() {
        isRefreshingPorts = true
        Task {
            let entries = await Self.fetchPortEntries()
            portEntries = entries
            isRefreshingPorts = false
        }
    }

    func killProcess(portEntry: PortEntry) {
        kill(portEntry.pid, SIGKILL)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refreshPorts()
        }
    }

    private static func fetchPortEntries() async -> [PortEntry] {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
            process.arguments = ["-iTCP", "-P", "-n", "-sTCP:LISTEN"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            try? process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return parseLsofOutput(data)
        }.value
    }

    nonisolated private static func parseLsofOutput(_ data: Data) -> [PortEntry] {
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        var entries: [PortEntry] = []
        for line in output.components(separatedBy: .newlines).dropFirst() {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 2, let pid = Int32(parts[1]) else { continue }
            let name = String(parts[0])
            for part in parts.dropFirst(2) {
                let s = String(part)
                if s.contains(":"),
                   let last = s.split(separator: ":").last.flatMap({ Int($0.replacingOccurrences(of: "(", with: "")) }) {
                    entries.append(PortEntry(port: last, processName: name, pid: pid))
                    break
                }
            }
        }
        return entries.sorted { $0.port < $1.port }
    }
}
