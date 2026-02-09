//
//  TaskMonitorContentView.swift
//  TaskMonitor
//
//  Two tabs: Applications (with end button), Port (processes using ports).
//

import SwiftUI
import AppKit

enum TaskMonitorTab: String, CaseIterable {
    case applications = "Applications"
    case port = "Port"
}

struct TaskMonitorContentView: View {
    @StateObject private var viewModel = TaskMonitorViewModel()
    @State private var selectedTab: TaskMonitorTab = .applications
    @State private var secondsUntilRefresh: Int = 3

    var body: some View {
        VStack(spacing: 0) {
            ThemedSegmentedPicker(selection: $selectedTab, items: TaskMonitorTab.allCases) { $0.rawValue }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)

            switch selectedTab {
            case .applications:
                applicationsTab
            case .port:
                portTab
            }
            bottomToolbar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themedBackground(.primary)
        .onAppear {
            viewModel.refreshAll()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if secondsUntilRefresh <= 0 {
                viewModel.refreshAll()
                secondsUntilRefresh = 3
            } else {
                secondsUntilRefresh -= 1
            }
        }
    }

    private var applicationsTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button("Filter System applications") {
                    viewModel.filterSystemApps.toggle()
                }
                .secondaryButtonStyle()
                .background(viewModel.filterSystemApps ? Color.accentColor.opacity(0.25) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                        .strokeBorder(viewModel.filterSystemApps ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                )
                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.xs)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    ForEach(viewModel.displayedApplications) { app in
                        HStack {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            }
                            Text(app.name)
                                .font(.system(size: AppTheme.FontSize.body))
                                .foregroundColor(AppTheme.primaryText)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Button {
                                viewModel.terminate(app)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.error)
                            }
                            .buttonStyle(.plain)
                            .help("End application")
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(AppTheme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var portTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            ThemedSectionHeader("Processes using ports")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    ForEach(viewModel.portEntries) { entry in
                        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                            Text("\(entry.port)")
                                .font(.system(size: AppTheme.FontSize.body, design: .monospaced))
                                .foregroundColor(AppTheme.secondaryText)
                                .frame(width: 56, alignment: .leading)
                            Text(entry.processName)
                                .font(.system(size: AppTheme.FontSize.body))
                                .foregroundColor(AppTheme.primaryText)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Button {
                                viewModel.killProcess(portEntry: entry)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.error)
                            }
                            .buttonStyle(.plain)
                            .help("Kill process")
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(AppTheme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.leading, AppTheme.Spacing.lg)
        .padding(.trailing, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private var bottomToolbar: some View {
        AppBottomToolbar(trailing: {
            Text("Auto refreshes in \(secondsUntilRefresh)s")
                .font(.system(size: AppTheme.FontSize.caption))
                .foregroundColor(AppTheme.secondaryText)
            Button(action: {
                viewModel.refreshAll()
                secondsUntilRefresh = 3
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: AppTheme.FontSize.subheadline))
            }
            .buttonStyle(.plain)
            .help("Refresh")
        })
    }
}
