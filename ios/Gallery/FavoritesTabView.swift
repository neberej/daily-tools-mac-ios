//
//  FavoritesTabView.swift
//  Gallery
//

import SwiftUI
import Photos

struct FavoritesTabView: View {
    @Binding var sortNewestFirst: Bool
    @EnvironmentObject var library: PhotoLibraryService
    @State private var assets: [PHAsset] = []
    @State private var selectedPhotoIndex: Int?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    private var thumbnailCellSize: CGFloat { (UIScreen.main.bounds.width - 4) / 3 }

    var body: some View {
        NavigationStack {
            ZStack {
                if assets.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No Favorites")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("Photos you favorite will appear here.")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { _, asset in
                                PhotoThumbnailView(asset: asset, cellSize: thumbnailCellSize)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if let idx = assets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) {
                                            selectedPhotoIndex = idx
                                        }
                                    }
                            }
                        }
                        .padding(2)
                        .padding(.bottom, 100)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { reloadFavorites() }
        .onChange(of: sortNewestFirst) { _, _ in reloadFavorites() }
        .fullScreenCover(isPresented: Binding(
            get: { selectedPhotoIndex != nil },
            set: { if !$0 { selectedPhotoIndex = nil } }
        )) {
            if let idx = selectedPhotoIndex, !assets.isEmpty, idx >= 0, idx < assets.count {
                FullScreenPhotoView(
                    initialAssetId: assets[idx].localIdentifier,
                    onDismiss: { selectedPhotoIndex = nil },
                    scopedAssets: assets
                )
            }
        }
    }

    private func reloadFavorites() {
        guard let favCollection = fetchFavoritesCollection() else {
            assets = []
            return
        }
        assets = library.loadAssets(in: favCollection, sortNewestFirst: sortNewestFirst)
    }

    private func fetchFavoritesCollection() -> PHAssetCollection? {
        let result = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumFavorites,
            options: nil
        )
        return result.firstObject
    }
}
