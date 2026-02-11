//
//  PhotosTabView.swift
//  Gallery
//

import SwiftUI

struct PhotosTabView: View {
    @EnvironmentObject var library: PhotoLibraryService
    @Binding var sortNewestFirst: Bool
    @Binding var scrollToEdge: ContentView.ScrollEdge?
    @State private var selectedAssetId: String?
    @State private var didInitialScroll = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
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
                                        selectedAssetId = asset.localIdentifier
                                    }
                            }
                        }
                        .padding(2)
                        .padding(.bottom, 100)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: library.allAssets.count) { _, _ in
                        guard !didInitialScroll else { return }
                        if let lastId = library.allAssets.last?.localIdentifier {
                            proxy.scrollTo(lastId, anchor: .bottom)
                            didInitialScroll = true
                        }
                    }
                    .onAppear {
                        if !didInitialScroll, let lastId = library.allAssets.last?.localIdentifier {
                            proxy.scrollTo(lastId, anchor: .bottom)
                            didInitialScroll = true
                        }
                    }
                    .onChange(of: scrollToEdge) { _, edge in
                        guard let edge else { return }
                        withAnimation {
                            switch edge {
                            case .top:
                                if let firstId = library.allAssets.first?.localIdentifier {
                                    proxy.scrollTo(firstId, anchor: .top)
                                }
                            case .bottom:
                                if let lastId = library.allAssets.last?.localIdentifier {
                                    proxy.scrollTo(lastId, anchor: .bottom)
                                }
                            }
                        }
                        scrollToEdge = nil
                    }
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedAssetId != nil },
            set: { if !$0 { selectedAssetId = nil } }
        )) {
            if let assetId = selectedAssetId {
                FullScreenPhotoView(
                    initialAssetId: assetId,
                    onDismiss: { selectedAssetId = nil }
                )
                .environmentObject(library)
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
    PhotosTabView(sortNewestFirst: .constant(true), scrollToEdge: .constant(nil))
        .environmentObject(PhotoLibraryService())
}
