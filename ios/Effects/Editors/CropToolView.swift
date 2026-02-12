//
//  CropToolView.swift
//  Effects
//

import SwiftUI

struct CropToolView: View {
    @Binding var image: UIImage

    @State private var cropRect: CGRect = .zero
    @State private var imageFrame: CGRect = .zero
    @State private var isDragging = false

    // Which handle is being dragged
    @State private var activeEdge: Edge.Set = []
    @State private var dragStart: CGPoint = .zero

    private let handleSize: CGFloat = 28
    private let minCropSize: CGFloat = 60

    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { geo in
                let fitting = fittedImageRect(in: geo.size)

                ZStack {
                    // Source image
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: fitting.width, height: fitting.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)

                    // Dimmed overlay outside crop
                    cropOverlay(fitting: fitting, containerSize: geo.size)

                    // Crop border + handles
                    cropBorder(fitting: fitting, containerSize: geo.size)
                }
                .onAppear {
                    imageFrame = fitting
                    let inset: CGFloat = 20
                    cropRect = CGRect(
                        x: fitting.minX + inset,
                        y: fitting.minY + inset,
                        width: fitting.width - inset * 2,
                        height: fitting.height - inset * 2
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Apply button
            Button {
                applyCrop()
            } label: {
                Text("Apply Crop")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Fitted Rect

    private func fittedImageRect(in containerSize: CGSize) -> CGRect {
        let imgSize = image.size
        guard imgSize.width > 0, imgSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let scale = min(containerSize.width / imgSize.width, containerSize.height / imgSize.height)
        let w = imgSize.width * scale
        let h = imgSize.height * scale
        return CGRect(
            x: (containerSize.width - w) / 2,
            y: (containerSize.height - h) / 2,
            width: w,
            height: h
        )
    }

    // MARK: - Dimmed Overlay

    private func cropOverlay(fitting: CGRect, containerSize: CGSize) -> some View {
        Canvas { ctx, size in
            // Full dim
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.55)))
            // Clear crop area
            ctx.blendMode = .destinationOut
            ctx.fill(Path(cropRect), with: .color(.white))
        }
        .allowsHitTesting(false)
        .compositingGroup()
    }

    // MARK: - Crop Border + Handles

    private func cropBorder(fitting: CGRect, containerSize: CGSize) -> some View {
        ZStack {
            // Border
            Rectangle()
                .strokeBorder(.white, lineWidth: 1.5)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)

            // Grid lines (rule of thirds)
            gridLines

            // Corner handles
            cornerHandle(x: cropRect.minX, y: cropRect.minY, edges: [.leading, .top])
            cornerHandle(x: cropRect.maxX, y: cropRect.minY, edges: [.trailing, .top])
            cornerHandle(x: cropRect.minX, y: cropRect.maxY, edges: [.leading, .bottom])
            cornerHandle(x: cropRect.maxX, y: cropRect.maxY, edges: [.trailing, .bottom])

            // Move entire crop area
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .frame(width: max(0, cropRect.width - handleSize * 2),
                       height: max(0, cropRect.height - handleSize * 2))
                .position(x: cropRect.midX, y: cropRect.midY)
                .gesture(moveDragGesture(fitting: fitting))
        }
    }

    private var gridLines: some View {
        Canvas { ctx, _ in
            let thirdW = cropRect.width / 3
            let thirdH = cropRect.height / 3
            var path = Path()
            // Vertical lines
            for i in 1...2 {
                let x = cropRect.minX + thirdW * CGFloat(i)
                path.move(to: CGPoint(x: x, y: cropRect.minY))
                path.addLine(to: CGPoint(x: x, y: cropRect.maxY))
            }
            // Horizontal lines
            for i in 1...2 {
                let y = cropRect.minY + thirdH * CGFloat(i)
                path.move(to: CGPoint(x: cropRect.minX, y: y))
                path.addLine(to: CGPoint(x: cropRect.maxX, y: y))
            }
            ctx.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }

    private func cornerHandle(x: CGFloat, y: CGFloat, edges: Edge.Set) -> some View {
        Circle()
            .fill(.white)
            .frame(width: handleSize, height: handleSize)
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            .position(x: x, y: y)
            .gesture(resizeDragGesture(edges: edges, fitting: imageFrame))
    }

    // MARK: - Gestures

    private func resizeDragGesture(edges: Edge.Set, fitting: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                var newRect = cropRect

                if edges.contains(.leading) {
                    let newX = min(value.location.x, newRect.maxX - minCropSize)
                    let clampedX = max(newX, fitting.minX)
                    newRect.size.width += newRect.minX - clampedX
                    newRect.origin.x = clampedX
                }
                if edges.contains(.trailing) {
                    let newMaxX = max(value.location.x, newRect.minX + minCropSize)
                    newRect.size.width = min(newMaxX, fitting.maxX) - newRect.minX
                }
                if edges.contains(.top) {
                    let newY = min(value.location.y, newRect.maxY - minCropSize)
                    let clampedY = max(newY, fitting.minY)
                    newRect.size.height += newRect.minY - clampedY
                    newRect.origin.y = clampedY
                }
                if edges.contains(.bottom) {
                    let newMaxY = max(value.location.y, newRect.minY + minCropSize)
                    newRect.size.height = min(newMaxY, fitting.maxY) - newRect.minY
                }

                cropRect = newRect
            }
    }

    private func moveDragGesture(fitting: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                var newRect = cropRect
                newRect.origin.x = max(fitting.minX, min(cropRect.origin.x + dx, fitting.maxX - cropRect.width))
                newRect.origin.y = max(fitting.minY, min(cropRect.origin.y + dy, fitting.maxY - cropRect.height))

                // Use predicted end for smoother tracking
                cropRect = newRect
            }
    }

    // MARK: - Apply

    private func applyCrop() {
        let imgSize = image.size
        guard imageFrame.width > 0, imageFrame.height > 0 else { return }

        let scaleX = imgSize.width / imageFrame.width
        let scaleY = imgSize.height / imageFrame.height

        let pixelRect = CGRect(
            x: (cropRect.minX - imageFrame.minX) * scaleX,
            y: (cropRect.minY - imageFrame.minY) * scaleY,
            width: cropRect.width * scaleX,
            height: cropRect.height * scaleY
        )

        guard let cgImage = image.cgImage?.cropping(to: pixelRect) else { return }
        image = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)

        // Reset crop rect to new image
        let newFitting = fittedImageRect(in: imageFrame.size)
        let inset: CGFloat = 20
        imageFrame = newFitting
        cropRect = CGRect(
            x: newFitting.minX + inset,
            y: newFitting.minY + inset,
            width: newFitting.width - inset * 2,
            height: newFitting.height - inset * 2
        )
    }
}
