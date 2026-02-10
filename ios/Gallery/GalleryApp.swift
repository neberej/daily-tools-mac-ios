//
//  GalleryApp.swift
//  Gallery
//

import SwiftUI

@main
struct GalleryApp: App {
    @StateObject private var library = PhotoLibraryService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
        }
    }
}
