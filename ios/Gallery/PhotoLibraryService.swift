//
//  PhotoLibraryService.swift
//  Gallery
//

import Foundation
import Photos
import UIKit

@MainActor
final class PhotoLibraryService: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published private(set) var allAssets: [PHAsset] = []
    @Published private(set) var albums: [AlbumItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    /// Call from views to report errors (e.g. create album failed).
    func reportError(_ message: String?) {
        errorMessage = message
    }

    private let imageManager = PHCachingImageManager()
    private let queue = DispatchQueue(label: "com.gallery.photolibrary", qos: .userInitiated)

    /// Thumbnail cache window (~2–3 screens).
    private let thumbnailSize = CGSize(width: 200, height: 200)
    private let preloadCount = 120
    private var cachedRange: Range<Int> = 0..<0

    /// Cached fetch for photos; we re-sort in memory when sort order changes to avoid re-fetching.
    private var allPhotosFetchResult: PHFetchResult<PHAsset>?
    private var currentPhotosSortNewestFirst: Bool = false

    override init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    // MARK: - PHPhotoLibraryChangeObserver

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            if allPhotosFetchResult != nil {
                applyPhotosSortAndPublish()
            } else if authorizationStatus == .authorized || authorizationStatus == .limited {
                performLoadPhotos(sortNewestFirst: currentPhotosSortNewestFirst)
            }
            if !albums.isEmpty {
                performLoadAlbums(sortNewestFirst: currentAlbumsSortNewestFirst)
            } else if authorizationStatus == .authorized || authorizationStatus == .limited {
                performLoadAlbums(sortNewestFirst: true)
            }
        }
    }

    private var currentAlbumsSortNewestFirst: Bool = true

    func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        return status == .authorized || status == .limited
    }

    func loadAllPhotos(sortNewestFirst: Bool) {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            loadIfAuthorized(sortNewestFirst: sortNewestFirst)
            return
        }
        currentPhotosSortNewestFirst = sortNewestFirst
        if let existing = allPhotosFetchResult, existing.count > 0 {
            applyPhotosSortAndPublish()
            return
        }
        performLoadPhotos(sortNewestFirst: sortNewestFirst)
    }

    private func loadIfAuthorized(sortNewestFirst: Bool) {
        Task {
            let granted = await requestAuthorization()
            if granted {
                currentPhotosSortNewestFirst = sortNewestFirst
                performLoadPhotos(sortNewestFirst: sortNewestFirst)
            } else {
                errorMessage = "Photo library access was denied."
            }
        }
    }

    private func performLoadPhotos(sortNewestFirst: Bool) {
        currentPhotosSortNewestFirst = sortNewestFirst
        queue.async { [weak self] in
            guard let self else { return }
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let result = PHAsset.fetchAssets(with: options)
            Task { @MainActor in
                self.allPhotosFetchResult = result
                self.applyPhotosSortAndPublish()
                self.errorMessage = nil
            }
        }
    }

    private func applyPhotosSortAndPublish() {
        guard let result = allPhotosFetchResult else { return }
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        if currentPhotosSortNewestFirst {
            assets.reverse()
        }
        allAssets = assets
        startCachingInitialThumbnails(for: allAssets)
    }

    // MARK: - Thumbnail caching (sliding window)

    private func startCachingInitialThumbnails(for assets: [PHAsset]) {
        let assetsToCache = Array(assets.suffix(preloadCount))
        guard !assetsToCache.isEmpty else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        imageManager.startCachingImages(
            for: assetsToCache,
            targetSize: thumbnailSize,
            contentMode: .aspectFill,
            options: options
        )
        let n = min(preloadCount, assets.count)
        cachedRange = (assets.count - n)..<assets.count
    }

    func thumbnailAppeared(at index: Int) {
        let buffer = 40
        let start = max(0, index - buffer)
        let end = min(allAssets.count, index + buffer + 1)
        let newRange = start..<end
        updateCaching(to: newRange)
    }

    private func updateCaching(to newRange: Range<Int>) {
        guard newRange != cachedRange, !allAssets.isEmpty else { return }
        let toCache = newRange.subtracting(cachedRange).filter { $0 < allAssets.count }
        let toStop = cachedRange.subtracting(newRange).filter { $0 < allAssets.count }
        let cacheAssets = toCache.map { allAssets[$0] }
        let stopAssets = toStop.map { allAssets[$0] }
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        if !cacheAssets.isEmpty {
            imageManager.startCachingImages(
                for: cacheAssets,
                targetSize: thumbnailSize,
                contentMode: .aspectFill,
                options: options
            )
        }
        if !stopAssets.isEmpty {
            imageManager.stopCachingImages(
                for: stopAssets,
                targetSize: thumbnailSize,
                contentMode: .aspectFill,
                options: options
            )
        }
        cachedRange = newRange
    }

    func loadAlbums(sortNewestFirst: Bool) {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            Task {
                let granted = await requestAuthorization()
                if granted {
                    performLoadAlbums(sortNewestFirst: sortNewestFirst)
                } else {
                    errorMessage = "Photo library access was denied."
                }
            }
            return
        }
        currentAlbumsSortNewestFirst = sortNewestFirst
        performLoadAlbums(sortNewestFirst: sortNewestFirst)
    }

    private func performLoadAlbums(sortNewestFirst: Bool) {
        currentAlbumsSortNewestFirst = sortNewestFirst
        queue.async { [weak self] in
            guard let self else { return }
            var items: [AlbumItem] = []

            let userAlbums = PHAssetCollection.fetchAssetCollections(
                with: .album,
                subtype: .any,
                options: nil
            )
            userAlbums.enumerateObjects { collection, _, _ in
                let count = PHAsset.fetchAssets(in: collection, options: nil).count
                if count > 0 {
                    items.append(AlbumItem(collection: collection, assetCount: count))
                }
            }

            let smartAlbums = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .any,
                options: nil
            )
            smartAlbums.enumerateObjects { collection, _, _ in
                // Only show key smart albums that users expect and can interact with.
                switch collection.assetCollectionSubtype {
                case .smartAlbumUserLibrary, .smartAlbumFavorites, .smartAlbumRecentlyAdded:
                    let count = PHAsset.fetchAssets(in: collection, options: nil).count
                    if count > 0 {
                        items.append(AlbumItem(collection: collection, assetCount: count))
                    }
                default:
                    break
                }
            }

            let sortOrder: (AlbumItem, AlbumItem) -> Bool = { a, b in
                let da = a.collection.startDate ?? .distantPast
                let db = b.collection.startDate ?? .distantPast
                return sortNewestFirst ? da > db : da < db
            }
            items.sort(by: sortOrder)

            Task { @MainActor in
                self.albums = items
                self.errorMessage = nil
            }
        }
    }

    /// Returns a key (representative) asset for the collection without enumerating the whole album. Use for album cover.
    func keyAsset(for collection: PHAssetCollection) -> PHAsset? {
        let keyAssets = PHAsset.fetchKeyAssets(in: collection, options: nil)
        return keyAssets?.firstObject as? PHAsset
    }

    func loadAssets(in collection: PHAssetCollection, sortNewestFirst: Bool) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: !sortNewestFirst)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let result = PHAsset.fetchAssets(in: collection, options: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    func requestImage(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode = .aspectFill, highQuality: Bool = false) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = highQuality ? .highQualityFormat : .opportunistic
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            let lock = NSLock()
            var didResume = false
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { image, _ in
                lock.lock()
                defer { lock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: image)
            }
        }
    }

    /// Opportunistic load: calls onUpdate every time a new image is delivered (blurry then sharp). Use for thumbnails so they sharpen after the first paint.
    func requestImageOpportunistic(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode = .aspectFill, onUpdate: @escaping (UIImage?, Bool) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: contentMode,
            options: options
        ) { image, info in
            guard let image else { return }
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            Task { @MainActor in
                onUpdate(image, degraded)
            }
        }
    }

    /// Synchronous fast path: returns immediately if thumbnail is in the caching image manager's cache. Use in onAppear for instant paint; fall back to async requestImage when nil.
    func requestCachedThumbnail(for asset: PHAsset, targetSize: CGSize) -> UIImage? {
        var result: UIImage?
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            result = image
        }
        return result
    }

    func createAlbum(title: String) async throws -> PHAssetCollection? {
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
            } completionHandler: { success, error in
                if success {
                    let fetch = PHAssetCollection.fetchAssetCollections(
                        with: .album,
                        subtype: .any,
                        options: nil
                    )
                    var created: PHAssetCollection?
                    fetch.enumerateObjects { col, _, stop in
                        if col.localizedTitle == title {
                            created = col
                            stop.pointee = true
                        }
                    }
                    continuation.resume(returning: created)
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "Gallery", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create album"]))
                }
            }
        }
    }

    func addAssets(_ assets: [PHAsset], to collection: PHAssetCollection) async throws {
        try await performAddAssets(assets, to: collection)
    }

    private func performAddAssets(_ assets: [PHAsset], to collection: PHAssetCollection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                guard let request = PHAssetCollectionChangeRequest(for: collection) else {
                    continuation.resume(throwing: NSError(domain: "Gallery", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot modify album"]))
                    return
                }
                request.addAssets(assets as NSArray)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "Gallery", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to add photos"]))
                }
            }
        }
    }

    func removeAssets(_ assets: [PHAsset], from collection: PHAssetCollection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                guard let request = PHAssetCollectionChangeRequest(for: collection) else {
                    continuation.resume(throwing: NSError(domain: "Gallery", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot modify album"]))
                    return
                }
                request.removeAssets(assets as NSArray)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "Gallery", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to remove photos"]))
                }
            }
        }
    }

    /// User-created albums and Favorites can be edited (add/remove). System smart albums generally cannot.
    func canEdit(collection: PHAssetCollection) -> Bool {
        if collection.assetCollectionType == .album { return true }
        if collection.assetCollectionSubtype == .smartAlbumFavorites { return true }
        return false
    }

    var canCreateAlbum: Bool {
        authorizationStatus == .authorized
    }

    /// Only user-created albums (not smart albums) can be deleted.
    func canDelete(collection: PHAssetCollection) -> Bool {
        collection.assetCollectionType == .album
    }

    func deleteAlbum(_ collection: PHAssetCollection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetCollectionChangeRequest.deleteAssetCollections([collection] as NSFastEnumeration)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "Gallery", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to delete album"]))
                }
            }
        }
    }
}

struct AlbumItem: Identifiable, Hashable {
    let id: String
    let collection: PHAssetCollection
    let assetCount: Int

    init(collection: PHAssetCollection, assetCount: Int) {
        self.collection = collection
        self.assetCount = assetCount
        self.id = collection.localIdentifier
    }

    var title: String {
        collection.localizedTitle ?? "Album"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AlbumItem, rhs: AlbumItem) -> Bool {
        lhs.id == rhs.id
    }
}

extension Range where Bound == Int {
    /// Indices in this range that are not in the other range.
    func subtracting(_ other: Range<Int>) -> [Int] {
        Array(self).filter { !other.contains($0) }
    }
}
