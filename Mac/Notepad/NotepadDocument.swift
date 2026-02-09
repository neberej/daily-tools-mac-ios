//
//  NotepadDocument.swift
//  Notepad
//
//  Document model for notepad with auto-save support.
//

import SwiftUI
import UniformTypeIdentifiers

struct NotepadDocument: FileDocument {
    var text: String = ""

    static var readableContentTypes: [UTType] { [.plainText, .utf8PlainText, .text] }
    static var writableContentTypes: [UTType] { [.plainText, .utf8PlainText] }

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}
