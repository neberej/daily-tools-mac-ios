//
//  PhotoPickerRepresentable.swift
//  Gallery
//

import SwiftUI
import Photos
import PhotosUI

/// Presents PHPicker configured with the photo library so we get asset identifiers for adding to albums.
struct PhotoPickerRepresentable: UIViewControllerRepresentable {
    @Binding var selectedIdentifiers: [String]
    @Environment(\.dismiss) private var dismiss
    var maxSelectionCount: Int = 100

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = maxSelectionCount
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerRepresentable

        init(_ parent: PhotoPickerRepresentable) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            let identifiers = results.compactMap(\.assetIdentifier)
            parent.selectedIdentifiers = identifiers
            parent.dismiss()
        }
    }
}
