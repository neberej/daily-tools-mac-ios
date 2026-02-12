//
//  RemoveBackgroundView.swift
//  Effects
//

import SwiftUI
import Vision
import CoreImage
import ImageIO

struct RemoveBackgroundView: View {
    @Binding var image: UIImage

    @State private var processedImage: UIImage?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showOriginal = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Preview
            ZStack {
                // Checkerboard background to show transparency
                if processedImage != nil && !showOriginal {
                    checkerboard
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Image(uiImage: showOriginal ? image : (processedImage ?? image))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                    )

                if isProcessing {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.black.opacity(0.5))
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                        Text("Removing background…")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .frame(maxHeight: 400)
            .padding(.horizontal, 24)

            Spacer()

            // Controls
            VStack(spacing: 12) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.red.opacity(0.8))
                }

                HStack(spacing: 16) {
                    // Compare button
                    if processedImage != nil {
                        Button {} label: {
                            Label("Compare", systemImage: "eye")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                            showOriginal = pressing
                        }, perform: {})
                    }

                    // Process / Apply
                    Button {
                        if processedImage != nil {
                            image = processedImage!
                            processedImage = nil
                        } else {
                            Task { await removeBackground() }
                        }
                    } label: {
                        Text(processedImage != nil ? "Apply" : "Remove Background")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessing)
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Checkerboard

    private var checkerboard: some View {
        Canvas { ctx, size in
            let tileSize: CGFloat = 12
            let rows = Int(ceil(size.height / tileSize))
            let cols = Int(ceil(size.width / tileSize))
            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(x: CGFloat(col) * tileSize, y: CGFloat(row) * tileSize,
                                      width: tileSize, height: tileSize)
                    ctx.fill(Path(rect), with: .color(isLight ? Color(white: 0.25) : Color(white: 0.18)))
                }
            }
        }
    }

    // MARK: - Background Removal

    private func removeBackground() async {
        isProcessing = true
        errorMessage = nil

        let result = await Task.detached { () -> UIImage? in
            return performSubjectLifting(from: image)
        }.value

        await MainActor.run {
            if let result {
                processedImage = result
            } else {
                errorMessage = "Could not remove background. Try a photo with a clear subject."
            }
            isProcessing = false
        }
    }

    /// Uses Vision framework to generate a foreground mask and composite onto transparent background.
    private func performSubjectLifting(from source: UIImage) -> UIImage? {
        guard let cgImage = source.cgImage else { return nil }

        // Build orientation-correct CIImage using CIImage(image:) which respects UIImage orientation
        guard var originalCIImage = CIImage(image: source) else { return nil }

        // Vision needs the cgImage directly — pass orientation so mask aligns correctly
        let orientation = CGImagePropertyOrientation(source.imageOrientation)
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let result = request.results?.first else { return nil }

        do {
            let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)

            let maskCIImage = CIImage(cvPixelBuffer: maskPixelBuffer)

            // Scale mask to match the oriented original
            let scaleX = originalCIImage.extent.width / maskCIImage.extent.width
            let scaleY = originalCIImage.extent.height / maskCIImage.extent.height
            let scaledMask = maskCIImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

            // Slight feather on mask edges for smoother cutout
            let feathered: CIImage
            if let blur = CIFilter(name: "CIGaussianBlur") {
                blur.setValue(scaledMask, forKey: kCIInputImageKey)
                blur.setValue(1.0, forKey: kCIInputRadiusKey)
                feathered = (blur.outputImage ?? scaledMask).cropped(to: originalCIImage.extent)
            } else {
                feathered = scaledMask
            }

            // Composite: foreground over transparent
            guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return nil }

            let transparentBg = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0))
                .cropped(to: originalCIImage.extent)

            blendFilter.setValue(originalCIImage, forKey: kCIInputImageKey)
            blendFilter.setValue(transparentBg, forKey: kCIInputBackgroundImageKey)
            blendFilter.setValue(feathered, forKey: kCIInputMaskImageKey)

            guard let outputCIImage = blendFilter.outputImage else { return nil }

            // Reuse shared CIContext instead of creating a new one
            guard let outputCGImage = EffectRenderer.context.createCGImage(outputCIImage, from: outputCIImage.extent) else { return nil }

            return UIImage(cgImage: outputCGImage)
        } catch {
            return nil
        }
    }
}
