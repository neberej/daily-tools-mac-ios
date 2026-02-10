//
//  AddToAlbumSheetView.swift
//  Gallery
//

import SwiftUI
import Photos

struct AddToAlbumSheetView: View {
    let asset: PHAsset
    let onDismiss: () -> Void
    let onAdded: (String) -> Void

    @EnvironmentObject var library: PhotoLibraryService
    @State private var errorMessage: String?
    @State private var showCreateAlbum = false
    @State private var newAlbumName = ""

    private var editableAlbums: [AlbumItem] {
        library.albums.filter { library.canEdit(collection: $0.collection) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(editableAlbums) { album in
                    Button {
                        addPhoto(to: album)
                    } label: {
                        HStack {
                            Text(album.title)
                            Spacer()
                            Text("\(album.assetCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add to Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Album") {
                        showCreateAlbum = true
                    }
                }
            }
            .onAppear {
                library.loadAlbums(sortNewestFirst: true)
            }
            .sheet(isPresented: $showCreateAlbum) {
                createAlbumSheet
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var createAlbumSheet: some View {
        NavigationStack {
            Form {
                TextField("Album name", text: $newAlbumName)
                    .textInputAutocapitalization(.words)
            }
            .navigationTitle("New Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showCreateAlbum = false
                        newAlbumName = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            do {
                                guard let newAlbum = try await library.createAlbum(title: newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                                    await MainActor.run { errorMessage = "Could not create album." }
                                    return
                                }
                                await MainActor.run {
                                    library.loadAlbums(sortNewestFirst: true)
                                    showCreateAlbum = false
                                    newAlbumName = ""
                                }
                                try await library.addAssets([asset], to: newAlbum)
                                await MainActor.run {
                                    onAdded("Created \"\(newAlbum.localizedTitle ?? "Album")\" and added photo.")
                                }
                            } catch {
                                await MainActor.run {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    }
                    .disabled(newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func addPhoto(to album: AlbumItem) {
        Task {
            do {
                try await library.addAssets([asset], to: album.collection)
                await MainActor.run {
                    onAdded("Added to \"\(album.title)\"")
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
