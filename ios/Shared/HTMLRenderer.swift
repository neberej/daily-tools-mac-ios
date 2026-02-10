//
//  HTMLRenderer.swift
//  Shared
//

import SwiftUI

enum HTMLRenderer {
    /// Converts an HTML string (from HN API) into a styled AttributedString.
    static func render(_ html: String) -> AttributedString {
        // Wrap in a styled HTML document for NSAttributedString parsing
        let wrapped = """
        <html><head><style>
        body { font-family: -apple-system; font-size: 15px; color: #e0e0e0; }
        a { color: #FF9500; text-decoration: none; }
        pre, code { font-family: Menlo; font-size: 13px; background: rgba(255,255,255,0.05); padding: 2px 4px; border-radius: 4px; }
        p { margin: 4px 0; }
        </style></head><body>\(html)</body></html>
        """

        guard let data = wrapped.data(using: .utf8),
              let nsAttr = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            return AttributedString(html)
        }

        do {
            return try AttributedString(nsAttr, including: \.uiKit)
        } catch {
            return AttributedString(nsAttr.string)
        }
    }

    /// Strips HTML tags for a plain-text preview.
    static func plainText(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
