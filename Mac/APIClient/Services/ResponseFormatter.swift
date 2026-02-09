//
//  ResponseFormatter.swift
//  APIClient
//
//  Centralizes response body formatting (content sniffing, JSON, string decode).
//  Extend with XML, HTML, or binary preview by adding branches here.
//

import Foundation

enum ResponseFormatter {
    /// Format response body for display. Prefer pretty-printed JSON when valid; otherwise UTF-8 string.
    static func format(data: Data, headers: [String: String]) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) {
            return str
        }
        return String(data: data, encoding: .utf8) ?? "(invalid encoding)"
    }
}
