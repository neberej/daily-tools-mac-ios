//
//  ImageViewerContentView.swift
//  ImageViewer
//
//  Main view: image with zoom/pan, bottom toolbar with New/Open/Save and zoom icons.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ImageViewerContentView: View {
    @StateObject private var viewModel = ImageViewerViewModel()
    @State private var showInfoSheet = false

    var body: some View {
        VStack(spacing: 0) {
            imageView
            bottomToolbar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themedBackground(.primary)
        .onReceive(NotificationCenter.default.publisher(for: .imageViewerOpen)) { _ in
            viewModel.openImage()
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url, url.isFileURL else { return }
                DispatchQueue.main.async { viewModel.loadImage(from: url) }
            }
            return true
        }
        .sheet(isPresented: $showInfoSheet) {
            if let info = viewModel.imageInfo {
                ImageInfoSheet(info: info)
                    .frame(minWidth: 320, minHeight: 200)
            }
        }
    }

    private var bottomToolbar: some View {
        AppBottomToolbar(
            new: { viewModel.clearImage() },
            open: { viewModel.openImage() },
            save: viewModel.currentImage != nil ? { viewModel.saveImage() } : nil,
            trailing: {
                HStack(spacing: AppTheme.Spacing.sm) {
                    if let name = viewModel.currentFileName {
                        Text(name)
                            .font(.system(size: AppTheme.FontSize.caption))
                            .foregroundColor(AppTheme.secondaryText)
                            .lineLimit(1)
                            .frame(maxWidth: 120, alignment: .trailing)
                    }
                    if viewModel.currentImage != nil {
                        Button(action: { viewModel.removeWhiteBackground() }) {
                            Image(systemName: "square.dashed")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .help("Remove white background")
                        Button(action: {
                            viewModel.loadImageInfo()
                            showInfoSheet = true
                        }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .help("Image info & EXIF")
                        Button(action: { viewModel.zoomIn() }) {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .help("Zoom In")
                        .keyboardShortcut("+", modifiers: .command)
                        Button(action: { viewModel.zoomOut() }) {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .help("Zoom Out")
                        .keyboardShortcut("-", modifiers: .command)
                        Button(action: { viewModel.zoomReset() }) {
                            Image(systemName: "1.square")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .help("Actual Size")
                        .keyboardShortcut("0", modifiers: .command)
                    }
                }
            }
        )
    }

    private var imageView: some View {
        GeometryReader { geo in
            if let nsImage = viewModel.currentImage {
                ImageViewerZoomView(
                    image: nsImage,
                    scale: $viewModel.scale,
                    offset: $viewModel.offset
                )
                .frame(width: geo.size.width, height: geo.size.height)
            } else {
                VStack(spacing: AppTheme.Spacing.lg) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.tertiaryText)
                    Text("Open an image to view")
                        .font(.system(size: AppTheme.FontSize.body))
                        .foregroundColor(AppTheme.secondaryText)
                    Button("Open Image…") { viewModel.openImage() }
                        .primaryButtonStyle()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Image info sheet (size + EXIF)

struct ImageInfoSheet: View {
    let info: ImageViewerViewModel.ImageInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Text("Image info")
                    .font(.system(size: AppTheme.FontSize.headline, weight: .semibold))
                    .foregroundColor(AppTheme.primaryText)
                Spacer(minLength: 0)
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.secondaryText)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Size (pixels): \(info.sizePixels)")
                    .font(.system(size: AppTheme.FontSize.body))
                    .foregroundColor(AppTheme.primaryText)
                Text("Size (points): \(info.sizePoints)")
                    .font(.system(size: AppTheme.FontSize.body))
                    .foregroundColor(AppTheme.primaryText)
            }
            if !info.exifLines.isEmpty {
                ThemedSectionHeader("EXIF")
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    ForEach(info.exifLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: AppTheme.FontSize.subheadline, design: .monospaced))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
