//
//  APIClientContentView.swift
//  APIClient
//
//  Layout: Left = saved requests. Right = Request (URL | Headers | Body tabs) + Body (Body | Headers tabs, Beautify JSON).
//

import SwiftUI

enum RequestTab: String, CaseIterable {
    case url = "URL"
    case headers = "Headers"
    case body = "Body"
}

enum ResponseTab: String, CaseIterable {
    case body = "Body"
    case headers = "Headers"
}

struct APIClientContentView: View {
    @StateObject private var viewModel = APIClientViewModel()
    @State private var requestTab: RequestTab = .url
    @State private var responseTab: ResponseTab = .body
    @State private var requestIdToRename: UUID?
    @State private var renameText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                sidebar
                rightContent
            }
            bottomToolbar
        }
        .themedBackground(.primary)
        .onReceive(NotificationCenter.default.publisher(for: .apiClientSendRequest)) { _ in
            viewModel.sendRequest()
        }
        .sheet(isPresented: Binding(
            get: { requestIdToRename != nil },
            set: { if !$0 { requestIdToRename = nil } }
        )) {
            if let id = requestIdToRename {
                renameSheet(requestId: id)
            }
        }
    }

    @ViewBuilder
    private func renameSheet(requestId: UUID) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            Text("Rename request")
                .font(.system(size: AppTheme.FontSize.headline, weight: .semibold))
                .foregroundColor(AppTheme.primaryText)
            TextField("Name", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: AppTheme.FontSize.body))
            HStack {
                Spacer()
                Button("Cancel") {
                    requestIdToRename = nil
                }
                .keyboardShortcut(.cancelAction)
                Button("Rename") {
                    viewModel.renameRequest(id: requestId, name: renameText)
                    requestIdToRename = nil
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(AppTheme.Spacing.xl)
        .frame(minWidth: 320)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            ThemedSectionHeader("Request History")
            List {
                ForEach(viewModel.requests) { req in
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Button {
                            viewModel.selectRequest(id: req.id)
                        } label: {
                            HStack(spacing: 0) {
                                Text(methodBadge(req.method))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(methodColor(req.method))
                                    .frame(width: 36, alignment: .leading)
                                Text(req.name)
                                    .lineLimit(1)
                                    .foregroundColor(AppTheme.primaryText)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Button {
                            requestIdToRename = req.id
                            renameText = req.name
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.secondaryText)
                                .frame(minWidth: 24, minHeight: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Rename")
                    }
                    .listRowBackground(
                        viewModel.selectedRequestId == req.id
                            ? Color.accentColor.opacity(0.2)
                            : Color.clear
                    )
                    .contextMenu {
                        Button("Rename…") {
                            requestIdToRename = req.id
                            renameText = req.name
                        }
                    }
                }
                .onMove(perform: viewModel.moveRequest)
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: 200, maxWidth: 280)
        .background(AppTheme.secondaryBackground)
    }

    private var rightContent: some View {
        VSplitView {
            requestSection
            responseSection
        }
    }

    private var requestSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("Request:")
                .font(.system(size: AppTheme.FontSize.caption, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ThemedSegmentedPicker(selection: $requestTab, items: RequestTab.allCases) { $0.rawValue }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.xs)
                switch requestTab {
                case .url:
                    urlTabContent
                case .headers:
                    headersTabContent
                case .body:
                    bodyTabContent
                }
                }
            }
            .frame(minHeight: 120)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.sm)
        .frame(minHeight: 140)
    }

    private static let methodDropdownItems: [RequestMethod] = [.GET, .POST, .PUT, .PATCH, .DELETE]

    private var urlTabContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppTheme.Spacing.sm) {
                TextField("URL", text: viewModel.draftUrlString)
                    .textFieldStyle(.plain)
                    .font(.system(size: AppTheme.FontSize.body))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                Picker("", selection: viewModel.draftMethod) {
                    ForEach(Self.methodDropdownItems, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
                Button(action: { viewModel.sendRequest() }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Send")
                .frame(width: 32, height: 22)
                .background(AppTheme.primary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(AppTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private var bodyTabContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.draft.method != .GET {
                ThemedSectionHeader("Body")
                TextEditor(text: viewModel.draftBody)
                    .themedTextEditor()
                    .frame(minHeight: 80)
                    .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private var headersTabContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ThemedSectionHeader("Headers")
            headersTable
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private var headersTable: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            ForEach(viewModel.draft.headers) { header in
                HStack(spacing: AppTheme.Spacing.xs) {
                    Toggle("", isOn: viewModel.draftHeaderEnabledBinding(for: header.id))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                    TextField("Key", text: viewModel.draftHeaderKeyBinding(for: header.id))
                        .textFieldStyle(.plain)
                        .font(.system(size: AppTheme.FontSize.subheadline))
                    TextField("Value", text: viewModel.draftHeaderValueBinding(for: header.id))
                        .textFieldStyle(.plain)
                        .font(.system(size: AppTheme.FontSize.subheadline))
                }
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xs)
            }
            Button("Add header") { viewModel.addHeader() }
                .secondaryButtonStyle()
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("Body:")
                .font(.system(size: AppTheme.FontSize.caption, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText)
            VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ThemedSegmentedPicker(selection: $responseTab, items: ResponseTab.allCases) { $0.rawValue }
                    .padding(.vertical, AppTheme.Spacing.xs)
                HStack(spacing: AppTheme.Spacing.sm) {
                    if let status = viewModel.responseStatus {
                        Text("\(status)")
                            .font(.system(size: AppTheme.FontSize.subheadline, weight: .semibold))
                            .foregroundColor(statusColor(status))
                    }
                    if let duration = viewModel.responseDuration {
                        Text(String(format: "%.2fs", duration))
                            .font(.system(size: AppTheme.FontSize.caption))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
                .frame(minWidth: 100, alignment: .leading)
                Spacer()
                if responseTab == .body {
                    Button(action: { viewModel.beautifyResponseJSON() }) {
                        Text("{}")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                    }
                    .buttonStyle(.plain)
                    .help("Beautify JSON")
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.xs)
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch responseTab {
                case .body:
                    ScrollView {
                        Text(viewModel.responseText)
                            .font(.system(size: AppTheme.FontSize.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(AppTheme.Spacing.md)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.tertiaryBackground)
                case .headers:
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            ForEach(Array(viewModel.responseHeaders.keys.sorted()), id: \.self) { key in
                                if let value = viewModel.responseHeaders[key] {
                                    HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                                        Text(key)
                                            .font(.system(size: AppTheme.FontSize.subheadline, design: .monospaced))
                                            .foregroundColor(AppTheme.secondaryText)
                                            .frame(width: 180, alignment: .leading)
                                        Text(value)
                                            .font(.system(size: AppTheme.FontSize.subheadline, design: .monospaced))
                                            .foregroundColor(AppTheme.primaryText)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                        .padding(AppTheme.Spacing.md)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.tertiaryBackground)
                }
            }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.sm)
        .frame(minHeight: 200)
    }

    private var bottomToolbar: some View {
        AppBottomToolbar(
            new: { viewModel.addRequest() },
            open: { viewModel.loadCollection() },
            save: { viewModel.saveCollection() },
            trailing: {
                HStack(spacing: AppTheme.Spacing.md) {
                    if let name = viewModel.collectionFileURL?.lastPathComponent {
                        HStack(spacing: AppTheme.Spacing.xs) {
                            Text(name)
                                .font(.system(size: AppTheme.FontSize.caption))
                                .foregroundColor(AppTheme.secondaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if viewModel.collectionLastSavedAt != nil {
                                Text("Saved")
                                    .font(.system(size: AppTheme.FontSize.caption))
                                    .foregroundColor(AppTheme.success)
                            }
                        }
                        .frame(maxWidth: 200, alignment: .trailing)
                    }
                    Button(action: { viewModel.sendRequest() }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: AppTheme.FontSize.subheadline))
                    }
                    .buttonStyle(.plain)
                    .help("Send Request")
                }
            }
        )
    }

    private func methodBadge(_ method: RequestMethod) -> String {
        method.rawValue
    }

    private func methodColor(_ method: RequestMethod) -> Color {
        switch method {
        case .GET: return AppTheme.success
        case .POST: return AppTheme.info
        case .PUT: return AppTheme.warning
        case .PATCH: return AppTheme.info
        case .DELETE: return AppTheme.error
        default: return AppTheme.secondaryText
        }
    }

    private func statusColor(_ status: Int) -> Color {
        if status >= 200 && status < 300 { return AppTheme.success }
        if status >= 300 && status < 400 { return AppTheme.info }
        if status >= 400 { return AppTheme.error }
        return AppTheme.secondaryText
    }
}
