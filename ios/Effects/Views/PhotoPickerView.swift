//
//  PhotoPickerView.swift
//  Effects
//

import PhotosUI
import SwiftUI
import UIKit

// MARK: - UIImage Orientation → EXIF

extension UIImage.Orientation {
    var exifOrientation: Int {
        switch self {
        case .up:            return 1
        case .down:          return 3
        case .left:          return 8
        case .right:         return 6
        case .upMirrored:    return 2
        case .downMirrored:  return 4
        case .leftMirrored:  return 5
        case .rightMirrored: return 7
        @unknown default:    return 1
        }
    }
}

// MARK: - UIImage Orientation → CGImagePropertyOrientation

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up:            self = .up
        case .down:          self = .down
        case .left:          self = .left
        case .right:         self = .right
        case .upMirrored:    self = .upMirrored
        case .downMirrored:  self = .downMirrored
        case .leftMirrored:  self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default:    self = .up
        }
    }
}

struct PhotoPickerView: View {
    @Binding var selectedCIImage: CIImage?
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(
            selection: $pickerItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            pickerLabel
        }
        .buttonStyle(.plain)
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await loadImage(from: newItem)
            }
        }
    }

    // MARK: - Label

    private var pickerLabel: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(.white.opacity(0.7))

            Text("Select a Photo")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("Choose a photo to start applying effects")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .glassCard()
        .padding(.horizontal, 32)
    }

    // MARK: - Loading (canonical: orientation-correct CIImage only)

    private func loadImage(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }

        guard var ciImage = CIImage(image: uiImage) else { return }
        ciImage = ciImage.oriented(forExifOrientation: Int32(uiImage.imageOrientation.exifOrientation))

        await MainActor.run {
            selectedCIImage = ciImage
        }
    }
}
