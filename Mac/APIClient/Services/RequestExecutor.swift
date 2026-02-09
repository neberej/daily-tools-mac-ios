//
//  RequestExecutor.swift
//  APIClient
//

import Foundation

struct RequestExecutor {
    struct Response {
        let statusCode: Int
        let headers: [String: String]
        let body: Data?
        let duration: TimeInterval
        let error: Error?
    }
    
    static func execute(
        method: RequestMethod,
        url: URL,
        headers: [HeaderItem],
        body: String?
    ) async -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        for h in headers where h.isEnabled && !h.key.isEmpty {
            request.setValue(h.value, forHTTPHeaderField: h.key)
        }
        
        if let body = body, !body.isEmpty,
           [.POST, .PUT, .PATCH].contains(method) {
            request.httpBody = body.data(using: .utf8)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            }
        }
        
        let start = Date()
        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            let duration = Date().timeIntervalSince(start)
            let http = urlResponse as? HTTPURLResponse
            let headerDict = (http?.allHeaderFields as? [String: Any])?.compactMapValues { "\($0)" } ?? [:]
            return Response(
                statusCode: http?.statusCode ?? 0,
                headers: headerDict,
                body: data,
                duration: duration,
                error: nil
            )
        } catch {
            return Response(
                statusCode: 0,
                headers: [:],
                body: nil,
                duration: Date().timeIntervalSince(start),
                error: error
            )
        }
    }
}
