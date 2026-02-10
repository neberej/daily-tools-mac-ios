//
//  PhotoThumbnailView.swift
//  Gallery
//

import SwiftUI
import Photos

struct PhotoThumbnailView: View {
    let asset: PHAsset
    /// Cell size (points); computed once by parent to avoid per-cell recalculation and to adapt to rotation/split view.
    let cellSize: CGFloat
    /// When non-nil, reports visibility for thumbnail cache window (Photos tab). Omit in album detail.
    var index: Int? = nil
    @EnvironmentObject var library: PhotoLibraryService
    @State private var image: UIImage?
    @State private var loadRequestId = 0

    private var targetSize: CGSize {
        CGSize(width: cellSize * UIScreen.main.scale, height: cellSize * UIScreen.main.scale)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.quaternary)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .clipped()
        .onAppear {
            if let index {
                library.thumbnailAppeared(at: index)
            }
            if image == nil {
                image = library.requestCachedThumbnail(for: asset, targetSize: targetSize)
                loadRequestId += 1
                let requestId = loadRequestId
                library.requestImageOpportunistic(for: asset, targetSize: targetSize, contentMode: .aspectFill) { newImage, degraded in
                    guard loadRequestId == requestId else { return }
                    if !degraded {
                        image = newImage
                    }
                }
            }
        }
        .onChange(of: asset.localIdentifier) { _, _ in
            image = nil
            loadRequestId += 1
            loadThumbnailIfNeeded()
        }
    }

    private func loadThumbnailIfNeeded() {
        guard image == nil else { return }
        image = library.requestCachedThumbnail(for: asset, targetSize: targetSize)
        if image == nil {
            loadRequestId += 1
            let requestId = loadRequestId
            library.requestImageOpportunistic(for: asset, targetSize: targetSize, contentMode: .aspectFill) { newImage, degraded in
                guard loadRequestId == requestId else { return }
                if !degraded {
                    image = newImage
                }
            }
        }
    }
}
