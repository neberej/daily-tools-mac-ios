//
//  EffectsExporter.swift
//  Effects
//

import Photos
import UIKit

enum EffectsExporter {

    /// Save the given UIImage to the "Effects" album.
    /// Assumes authorization was already granted at app start.
    @MainActor
    static func save(_ image: UIImage) async throws {
        let albumName = "Effects"

        // Check current status without re-prompting
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw ExportError.notAuthorized
        }

        // Find or create album
        let album = try await fetchOrCreateAlbum(named: albumName)

        // Save image into album
        try await PHPhotoLibrary.shared().performChanges {
            let creation = PHAssetChangeRequest.creationRequestForAsset(from: image)
            guard let placeholder = creation.placeholderForCreatedAsset else { return }
            let albumChange = PHAssetCollectionChangeRequest(for: album)
            albumChange?.addAssets([placeholder] as NSFastEnumeration)
        }
    }

    // MARK: - Private

    private static func fetchOrCreateAlbum(named name: String) async throws -> PHAssetCollection {
        // Check if album already exists
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", name)
        let existing = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        if let album = existing.firstObject {
            return album
        }

        // Create new album
        var placeholder: PHObjectPlaceholder?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            placeholder = request.placeholderForCreatedAssetCollection
        }

        guard let localID = placeholder?.localIdentifier else {
            throw ExportError.albumCreationFailed
        }

        let result = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [localID], options: nil)
        guard let album = result.firstObject else {
            throw ExportError.albumCreationFailed
        }
        return album
    }

    // MARK: - Errors

    enum ExportError: LocalizedError {
        case notAuthorized
        case albumCreationFailed

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Photo library access is required to save photos."
            case .albumCreationFailed:
                return "Could not create the Effects album."
            }
        }
    }
}
