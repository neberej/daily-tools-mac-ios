//
//  AlbumDetailView.swift
//  Gallery
//

import SwiftUI
import Photos

struct AlbumDetailView: View {
    let album: AlbumItem
    @Binding var sortNewestFirst: Bool
    @EnvironmentObject var library: PhotoLibraryService
    @State private var assets: [PHAsset] = []
    @State private var selection: Set<String> = []
    @State private var isSelectionMode = false
    @State private var showPhotoPicker = false
    @State private var pickedIdentifiers: [String] = []
    @State private var errorMessage: String?
    @State private var selectedPhotoIndex: Int?
    @State private var showDeleteAlbumConfirmation = false
    @State private var showRemovePhotosConfirmation = false
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    private var thumbnailCellSize: CGFloat { (UIScreen.main.bounds.width - 4) / 3 }
    private var canEdit: Bool { library.canEdit(collection: album.collection) }
    private var canDeleteAlbum: Bool { library.canDelete(collection: album.collection) }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { _, asset in
                        PhotoThumbnailView(asset: asset, cellSize: thumbnailCellSize)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isSelectionMode {
                                    toggleSelection(asset.localIdentifier)
                                } else {
                                    if let idx = assets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) {
                                        selectedPhotoIndex = idx
                                    }
                                }
                            }
                            .contextMenu {
                                if canEdit {
                                    Button(role: .destructive) {
                                        removeSingle(asset)
                                    } label: {
                                        Label("Remove from Album", systemImage: "trash")
                                    }
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                if isSelectionMode {
                                    Image(systemName: selection.contains(asset.localIdentifier) ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                        .foregroundStyle(selection.contains(asset.localIdentifier) ? .blue : .white)
                                        .shadow(radius: 2)
                                        .padding(6)
                                        .allowsHitTesting(false)
                                }
                            }
                            .opacity(isSelectionMode && selection.contains(asset.localIdentifier) ? 0.8 : 1)
                    }
                }
                .padding(2)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)

            if isSelectionMode, canEdit {
                selectionBar
            }
        }
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if canEdit, !isSelectionMode {
                    Menu {
                        Button {
                            showPhotoPicker = true
                        } label: {
                            Label("Add Photos", systemImage: "photo.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if canDeleteAlbum {
                    Menu {
                        if canEdit {
                            Button(isSelectionMode ? "Done" : "Select") {
                                withAnimation {
                                    isSelectionMode.toggle()
                                    if !isSelectionMode { selection.removeAll() }
                                }
                            }
                        }
                        Button(role: .destructive) {
                            showDeleteAlbumConfirmation = true
                        } label: {
                            Label("Delete Album", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                } else if canEdit {
                    Button(isSelectionMode ? "Done" : "Select") {
                        withAnimation {
                            isSelectionMode.toggle()
                            if !isSelectionMode { selection.removeAll() }
                        }
                    }
                }
            }
        }
        .onAppear {
            reloadAssets()
        }
        .onChange(of: sortNewestFirst) { _, _ in
            reloadAssets()
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerRepresentable(selectedIdentifiers: $pickedIdentifiers, maxSelectionCount: 100)
        }
        .onChange(of: pickedIdentifiers) { _, newValue in
            guard !newValue.isEmpty else { return }
            addPickedPhotos(identifiers: newValue)
            pickedIdentifiers = []
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedPhotoIndex != nil },
            set: { if !$0 { selectedPhotoIndex = nil } }
        )) {
            if let idx = selectedPhotoIndex, !assets.isEmpty, idx >= 0, idx < assets.count {
                FullScreenPhotoView(
                    assets: assets,
                    initialIndex: idx,
                    onDismiss: { selectedPhotoIndex = nil }
                )
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Delete Album?", isPresented: $showDeleteAlbumConfirmation) {
            Button("Cancel", role: .cancel) {
                showDeleteAlbumConfirmation = false
            }
            Button("Delete", role: .destructive) {
                deleteAlbum()
            }
        } message: {
            Text("“\(album.title)” will be deleted. Photos in it will not be removed from your library.")
        }
        .alert("Remove from Album?", isPresented: $showRemovePhotosConfirmation) {
            Button("Cancel", role: .cancel) {
                showRemovePhotosConfirmation = false
            }
            Button("Remove", role: .destructive) {
                removeSelected()
                showRemovePhotosConfirmation = false
            }
        } message: {
            Text("Remove \(selection.count) photo\(selection.count == 1 ? "" : "s") from this album? They will stay in your library.")
        }
    }

    private var selectionBar: some View {
        HStack {
            Button("Remove from Album") {
                showRemovePhotosConfirmation = true
            }
            .disabled(selection.isEmpty)
            .font(.subheadline.weight(.medium))

            Spacer()
            Text("\(selection.count) selected")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.bottom, 100)
    }

    private func reloadAssets() {
        assets = library.loadAssets(in: album.collection, sortNewestFirst: sortNewestFirst)
    }

    private func toggleSelection(_ id: String) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    /// Remove a single photo from this album (used by context menu). Only in album view.
    private func removeSingle(_ asset: PHAsset) {
        selection = [asset.localIdentifier]
        showRemovePhotosConfirmation = true
    }

    private func addPickedPhotos(identifiers: [String]) {
        Task {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            var toAdd: [PHAsset] = []
            fetchResult.enumerateObjects { asset, _, _ in
                toAdd.append(asset)
            }
            do {
                try await library.addAssets(toAdd, to: album.collection)
                await MainActor.run {
                    reloadAssets()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func removeSelected() {
        let toRemove = assets.filter { selection.contains($0.localIdentifier) }
        guard !toRemove.isEmpty else { return }
        Task {
            do {
                try await library.removeAssets(toRemove, from: album.collection)
                await MainActor.run {
                    selection.removeAll()
                    isSelectionMode = false
                    reloadAssets()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func deleteAlbum() {
        showDeleteAlbumConfirmation = false
        Task {
            do {
                try await library.deleteAlbum(album.collection)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
