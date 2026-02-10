//
//  PhotosTabView.swift
//  Gallery
//

import SwiftUI

struct PhotosTabView: View {
    @EnvironmentObject var library: PhotoLibraryService
    @Binding var sortNewestFirst: Bool
    @State private var selectedPhotoIndex: Int?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    /// Computed once in parent; passed to cells so they don't recalc on rotation/split view.
    private var thumbnailCellSize: CGFloat {
        (UIScreen.main.bounds.width - 4) / 3
    }

    var body: some View {
        Group {
            if library.authorizationStatus == .denied || library.authorizationStatus == .restricted {
                deniedView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(Array(library.allAssets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                PhotoThumbnailView(asset: asset, cellSize: thumbnailCellSize, index: index)
                                    .id(asset.localIdentifier)
                                    .onTapGesture {
                                        selectedPhotoIndex = index
                                    }
                            }
                        }
                        .padding(2)
                        .padding(.bottom, 100)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: library.allAssets.count) { _, count in
                        if count > 0, let lastId = library.allAssets.last?.localIdentifier {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                    .onAppear {
                        if !library.allAssets.isEmpty, let lastId = library.allAssets.last?.localIdentifier {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedPhotoIndex != nil },
            set: { if !$0 { selectedPhotoIndex = nil } }
        )) {
            if let idx = selectedPhotoIndex, !library.allAssets.isEmpty, idx >= 0, idx < library.allAssets.count {
                FullScreenPhotoView(
                    assets: library.allAssets,
                    initialIndex: idx,
                    onDismiss: { selectedPhotoIndex = nil }
                )
            }
        }
        .onAppear {
            library.loadAllPhotos(sortNewestFirst: sortNewestFirst)
        }
        .onChange(of: sortNewestFirst) { _, newValue in
            library.loadAllPhotos(sortNewestFirst: newValue)
        }
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Photo Access Needed")
                .font(.title2.weight(.semibold))
            Text("Allow access in Settings to view your photos.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PhotosTabView(sortNewestFirst: .constant(true))
        .environmentObject(PhotoLibraryService())
}
