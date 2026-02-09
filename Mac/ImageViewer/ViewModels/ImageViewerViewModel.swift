//
//  ImageViewerViewModel.swift
//  ImageViewer
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics

@MainActor
final class ImageViewerViewModel: ObservableObject {
    @Published var currentImage: NSImage?
    @Published var currentFileURL: URL?
    @Published var scale: CGFloat = 1
    @Published var offset: CGSize = .zero
    @Published var imageInfo: ImageInfo?

    var currentFileName: String? {
        currentFileURL?.lastPathComponent
    }

    struct ImageInfo {
        let sizePixels: String
        let sizePoints: String
        let exifLines: [String]
    }
    
    func openImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff, .heic]
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.loadImage(from: url)
        }
    }
    
    func loadImage(from url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        currentImage = image
        currentFileURL = url
        scale = 1
        offset = .zero
        imageInfo = nil
    }

    /// Makes near-white pixels transparent (threshold 0–255, default 250).
    func removeWhiteBackground(threshold: UInt8 = 250) {
        guard let image = currentImage else { return }
        let size = image.size
        let width = Int(size.width)
        let height = Int(size.height)
        guard width > 0, height > 0 else { return }
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        guard let mutableData = bitmap.bitmapData else { return }
        let bytesPerPixel = 4
        let bytesPerRow = bitmap.bytesPerRow
        for y in 0..<height {
            var row = mutableData.advanced(by: y * bytesPerRow)
            for _ in 0..<width {
                let r = row[0]
                let g = row[1]
                let b = row[2]
                if r >= threshold && g >= threshold && b >= threshold {
                    row[3] = 0
                }
                row = row.advanced(by: bytesPerPixel)
            }
        }
        let newImage = NSImage(size: size)
        newImage.addRepresentation(bitmap)
        currentImage = newImage
    }

    func loadImageInfo() {
        guard let url = currentFileURL, let image = currentImage else { return }
        var exifLines: [String] = []
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
            if let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                let keys: [(String, String)] = [
                    (kCGImagePropertyExifDateTimeOriginal as String, "Date"),
                    (kCGImagePropertyExifExposureTime as String, "Exposure"),
                    (kCGImagePropertyExifFNumber as String, "F-Number"),
                    (kCGImagePropertyExifISOSpeedRatings as String, "ISO"),
                    (kCGImagePropertyExifFocalLength as String, "Focal length"),
                ]
                for (k, label) in keys {
                    if let v = exif[k] {
                        exifLines.append("\(label): \(v)")
                    }
                }
            }
            if let width = props[kCGImagePropertyPixelWidth as String] as? Int,
               let height = props[kCGImagePropertyPixelHeight as String] as? Int {
                exifLines.insert("Dimensions: \(width) × \(height) px", at: 0)
            }
        }
        let sizePixels: String
        if let rep = image.representations.first as? NSBitmapImageRep {
            sizePixels = "\(rep.pixelsWide) × \(rep.pixelsHigh) px"
        } else {
            sizePixels = "\(Int(image.size.width)) × \(Int(image.size.height)) px"
        }
        let sizePoints = String(format: "%.0f × %.0f pt", image.size.width, image.size.height)
        imageInfo = ImageInfo(sizePixels: sizePixels, sizePoints: sizePoints, exifLines: exifLines)
    }
    
    func saveImage() {
        guard let image = currentImage else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = currentFileURL?.deletingPathExtension().lastPathComponent ?? "image"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            self.writeImage(image, to: url)
        }
    }
    
    private func writeImage(_ image: NSImage, to url: URL) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return }
        let ext = url.pathExtension.lowercased()
        let type: NSBitmapImageRep.FileType = ext == "png" ? .png : .jpeg
        let props: [NSBitmapImageRep.PropertyKey: Any] = type == .jpeg ? [.compressionFactor: 0.9] : [:]
        guard let data = rep.representation(using: type, properties: props) else { return }
        try? data.write(to: url)
    }
    
    func zoomIn() {
        scale = min(20, scale + 0.5)
    }
    
    func zoomOut() {
        scale = max(0.1, scale - 0.5)
    }
    
    func zoomReset() {
        scale = 1
        offset = .zero
    }

    func clearImage() {
        currentImage = nil
        currentFileURL = nil
        scale = 1
        offset = .zero
    }
}
