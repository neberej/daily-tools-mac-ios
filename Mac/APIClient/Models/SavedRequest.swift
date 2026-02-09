//
//  SavedRequest.swift
//  APIClient
//

import Foundation

struct SavedRequest: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var method: RequestMethod
    var urlString: String
    var headers: [HeaderItem]
    var body: String
    
    init(
        id: UUID = UUID(),
        name: String = "Untitled",
        method: RequestMethod = .GET,
        urlString: String = "",
        headers: [HeaderItem] = [],
        body: String = ""
    ) {
        self.id = id
        self.name = name
        self.method = method
        self.urlString = urlString
        self.headers = headers
        self.body = body
    }
}

struct HeaderItem: Identifiable, Codable, Equatable {
    var id: UUID
    var key: String
    var value: String
    var isEnabled: Bool
    
    init(id: UUID = UUID(), key: String = "", value: String = "", isEnabled: Bool = true) {
        self.id = id
        self.key = key
        self.value = value
        self.isEnabled = isEnabled
    }
}

struct RequestCollection: Codable {
    var name: String
    var requests: [SavedRequest]
    var updatedAt: Date
    
    init(name: String = "Collection", requests: [SavedRequest] = [], updatedAt: Date = Date()) {
        self.name = name
        self.requests = requests
        self.updatedAt = updatedAt
    }
}
