//
//  AlbumsTabView.swift
//  Gallery
//

import SwiftUI

struct AlbumsTabView: View {
    @EnvironmentObject var library: PhotoLibraryService
    @Binding var sortNewestFirst: Bool
    @State private var selectedAlbum: AlbumItem?
    @State private var showCreateAlbum = false
    @State private var newAlbumName = ""

    var body: some View {
        Group {
            if library.authorizationStatus == .denied || library.authorizationStatus == .restricted {
                deniedView
            } else {
                NavigationStack {
                    List {
                        ForEach(library.albums) { album in
                            Button {
                                selectedAlbum = album
                            } label: {
                                AlbumRowView(album: album, library: library)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .navigationTitle("Albums")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationDestination(item: $selectedAlbum) { album in
                        AlbumDetailView(
                            album: album,
                            sortNewestFirst: $sortNewestFirst
                        )
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .onAppear {
            library.loadAlbums(sortNewestFirst: sortNewestFirst)
        }
        .onChange(of: sortNewestFirst) { _, _ in
            library.loadAlbums(sortNewestFirst: sortNewestFirst)
        }
        .sheet(isPresented: $showCreateAlbum) {
            createAlbumSheet
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if library.canCreateAlbum {
                    Button {
                        showCreateAlbum = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
        }
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Photo Access Needed")
                .font(.title2.weight(.semibold))
            Text("Allow access in Settings to view your albums.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                                _ = try await library.createAlbum(title: newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines))
                                await MainActor.run {
                                    showCreateAlbum = false
                                    newAlbumName = ""
                                    library.loadAlbums(sortNewestFirst: sortNewestFirst)
                                }
                            } catch {
                                await MainActor.run {
                                    library.reportError(error.localizedDescription)
                                }
                            }
                        }
                    }
                    .disabled(newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct AlbumRowView: View {
    let album: AlbumItem
    @ObservedObject var library: PhotoLibraryService
    @State private var cover: UIImage?

    var body: some View {
        HStack(spacing: 16) {
            Group {
                if let cover {
                    Image(uiImage: cover)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay { Image(systemName: "photo.stack").foregroundStyle(.secondary) }
                }
            }
            .frame(width: 60, height: 60)
            .clipped()
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text("\(album.assetCount) photo\(album.assetCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .task(id: album.id) {
            guard let key = library.keyAsset(for: album.collection) else { return }
            let size = CGSize(width: 120, height: 120)
            cover = await library.requestImage(for: key, targetSize: size, contentMode: .aspectFill)
        }
    }
}

#Preview {
    AlbumsTabView(sortNewestFirst: .constant(true))
        .environmentObject(PhotoLibraryService())
}
