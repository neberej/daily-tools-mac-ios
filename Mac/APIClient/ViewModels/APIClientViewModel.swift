//
//  APIClientViewModel.swift
//  APIClient
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Request display name (URL parsing, fallback, formatting) for sidebar and future rename-on-edit
private enum RequestDisplayNaming {
    static func displayName(from urlString: String, untitledSuffix: Int) -> String {
        guard let url = parseURL(urlString), !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Untitled \(untitledSuffix)"
        }
        return formatDisplayName(from: url, fallback: "Untitled \(untitledSuffix)")
    }

    private static func parseURL(_ s: String) -> URL? {
        URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func formatDisplayName(from url: URL, fallback: String) -> String {
        if let host = url.host, !host.isEmpty {
            let path = url.path
            if path.isEmpty || path == "/" { return host }
            return (host + path).replacingOccurrences(of: "/", with: " ")
        }
        return url.lastPathComponent.isEmpty ? fallback : url.lastPathComponent
    }
}

struct RequestDraft {
    var method: RequestMethod = .GET
    var urlString: String = ""
    var headers: [HeaderItem] = [HeaderItem(key: "Accept", value: "application/json")]
    var body: String = ""
}

@MainActor
final class APIClientViewModel: ObservableObject {
    @Published var draft = RequestDraft()

    @Published var requests: [SavedRequest] = []
    @Published var selectedRequestId: UUID?
    @Published var collectionFileURL: URL?

    @Published var responseStatus: Int?
    @Published var responseDuration: TimeInterval?
    @Published var responseText: String = ""
    @Published var responseHeaders: [String: String] = [:]
    @Published var isLoading = false
    @Published var collectionLastSavedAt: Date?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    var selectedRequest: SavedRequest? {
        guard let id = selectedRequestId else { return nil }
        return requests.first { $0.id == id }
    }

    // MARK: - Draft bindings (intent methods replace draft so @Published fires; sync keeps sidebar in sync)

    private func updateDraft(_ transform: (inout RequestDraft) -> Void) {
        var next = draft
        transform(&next)
        draft = next
        syncDraftToSelectedRequest()
    }

    var draftMethod: Binding<RequestMethod> {
        Binding(get: { self.draft.method }, set: { newValue in self.updateDraft { $0.method = newValue } })
    }
    var draftUrlString: Binding<String> {
        Binding(get: { self.draft.urlString }, set: { newValue in self.updateDraft { $0.urlString = newValue } })
    }
    var draftBody: Binding<String> {
        Binding(get: { self.draft.body }, set: { newValue in self.updateDraft { $0.body = newValue } })
    }

    func draftHeaderKeyBinding(for headerId: UUID) -> Binding<String> {
        Binding(
            get: { self.draft.headers.first(where: { $0.id == headerId })?.key ?? "" },
            set: { [headerId] newValue in self.updateHeader(id: headerId) { $0.key = newValue } }
        )
    }
    func draftHeaderValueBinding(for headerId: UUID) -> Binding<String> {
        Binding(
            get: { self.draft.headers.first(where: { $0.id == headerId })?.value ?? "" },
            set: { [headerId] newValue in self.updateHeader(id: headerId) { $0.value = newValue } }
        )
    }
    func draftHeaderEnabledBinding(for headerId: UUID) -> Binding<Bool> {
        Binding(
            get: { self.draft.headers.first(where: { $0.id == headerId })?.isEnabled ?? true },
            set: { [headerId] newValue in self.updateHeader(id: headerId) { $0.isEnabled = newValue } }
        )
    }

    private func updateHeader(id headerId: UUID, _ transform: (inout HeaderItem) -> Void) {
        guard let index = draft.headers.firstIndex(where: { $0.id == headerId }) else {
            assertionFailure("Header id not found; index may be stale")
            return
        }
        updateDraft { draft in
            transform(&draft.headers[index])
        }
    }

    private func syncDraftToSelectedRequest() {
        guard let id = selectedRequestId, let index = requests.firstIndex(where: { $0.id == id }) else { return }
        requests[index].method = draft.method
        requests[index].urlString = draft.urlString
        requests[index].headers = draft.headers
        requests[index].body = draft.body
        requests[index].name = requestNameFromURL()
    }

    func addRequest() {
        let req = SavedRequest(
            name: requestNameFromURL(),
            method: draft.method,
            urlString: draft.urlString,
            headers: draft.headers,
            body: draft.body
        )
        requests.append(req)
        selectedRequestId = req.id
    }

    func saveCurrentRequest() {
        if let id = selectedRequestId, let index = requests.firstIndex(where: { $0.id == id }) {
            requests[index].method = draft.method
            requests[index].urlString = draft.urlString
            requests[index].headers = draft.headers
            requests[index].body = draft.body
        } else {
            addRequest()
        }
    }

    private func requestNameFromURL() -> String {
        RequestDisplayNaming.displayName(from: draft.urlString, untitledSuffix: requests.count + 1)
    }

    func addHeader() {
        updateDraft { $0.headers.append(HeaderItem()) }
    }

    func moveRequest(from source: IndexSet, to destination: Int) {
        requests.move(fromOffsets: source, toOffset: destination)
    }

    func moveHeader(from source: IndexSet, to destination: Int) {
        updateDraft { $0.headers.move(fromOffsets: source, toOffset: destination) }
    }

    func renameRequest(id: UUID, name: String) {
        guard let index = requests.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        requests[index].name = trimmed.isEmpty ? requests[index].name : trimmed
    }

    func sendRequest() {
        guard let url = URL(string: draft.urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme != nil else {
            responseText = "Invalid URL"
            responseStatus = nil
            return
        }
        isLoading = true
        responseText = ""
        responseStatus = nil
        responseDuration = nil
        responseHeaders = [:]
        Task {
            let response = await RequestExecutor.execute(
                method: draft.method,
                url: url,
                headers: draft.headers,
                body: draft.body.isEmpty ? nil : draft.body
            )
            await MainActor.run {
                isLoading = false
                responseStatus = response.statusCode
                responseDuration = response.duration
                responseHeaders = response.headers
                if let error = response.error {
                    responseText = "Error: \(error.localizedDescription)"
                } else if let data = response.body {
                    responseText = ResponseFormatter.format(data: data, headers: response.headers)
                } else {
                    responseText = "(empty body)"
                }
            }
        }
    }
    
    func saveCollection() {
        let collection = RequestCollection(
            name: "API Client Collection",
            requests: requests,
            updatedAt: Date()
        )
        if let url = collectionFileURL {
            let data = (try? encoder.encode(collection)) ?? Data()
            try? data.write(to: url, options: .atomic)
            setSavedIndicatorBriefly()
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = "api-collection.json"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self = self else { return }
            let data = (try? self.encoder.encode(collection)) ?? Data()
            try? data.write(to: url, options: .atomic)
            DispatchQueue.main.async {
                self.collectionFileURL = url
                self.setSavedIndicatorBriefly()
            }
        }
    }

    private func setSavedIndicatorBriefly() {
        collectionLastSavedAt = Date()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            collectionLastSavedAt = nil
        }
    }

    func loadCollection() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self = self else { return }
            guard let data = try? Data(contentsOf: url),
                  let collection = try? self.decoder.decode(RequestCollection.self, from: data) else {
                return
            }
            DispatchQueue.main.async {
                self.collectionFileURL = url
                self.requests = collection.requests
                self.selectRequest(id: self.requests.first?.id)
            }
        }
    }
    
    /// Call from row tap/button only (not from List binding) to avoid publishing during view updates.
    func selectRequest(id: UUID?) {
        if selectedRequestId == id { return }
        if let oldId = selectedRequestId,
           let index = requests.firstIndex(where: { $0.id == oldId }) {
            requests[index].method = draft.method
            requests[index].urlString = draft.urlString
            requests[index].headers = draft.headers
            requests[index].body = draft.body
        }
        selectedRequestId = id
        if let id, let req = requests.first(where: { $0.id == id }) {
            draft = RequestDraft(
                method: req.method,
                urlString: req.urlString,
                headers: req.headers,
                body: req.body
            )
        } else {
            draft = RequestDraft()
        }
        clearResponse()
    }

    private func clearResponse() {
        responseText = ""
        responseStatus = nil
        responseDuration = nil
        responseHeaders = [:]
    }

    func beautifyResponseJSON() {
        let trimmed = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else { return }
        responseText = str
    }
}
