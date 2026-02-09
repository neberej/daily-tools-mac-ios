//
//  NotepadSettingsView.swift
//  Notepad
//

import SwiftUI

struct NotepadSettingsView: View {
    @AppStorage("notepad.autoSaveInterval") private var autoSaveInterval: Double = 2.0
    @AppStorage("notepad.fontSize") private var fontSize: Double = 13
    
    var body: some View {
        Form {
            Section("Auto-save") {
                HStack {
                    Text("Save after idle (seconds)")
                    Slider(value: $autoSaveInterval, in: 1...10, step: 1)
                    Text("\(Int(autoSaveInterval))")
                        .frame(width: 24, alignment: .trailing)
                }
            }
            Section("Editor") {
                HStack {
                    Text("Font size")
                    Slider(value: $fontSize, in: 11...24, step: 1)
                    Text("\(Int(fontSize))")
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 200)
    }
}
