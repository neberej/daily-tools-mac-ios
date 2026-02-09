//
//  ImageViewerZoomView.swift
//  ImageViewer
//
//  Zoomable, pannable image view (Preview-like).
//

import SwiftUI
import AppKit

struct ImageViewerZoomView: View {
    let image: NSImage
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    @State private var dragStart: CGSize = .zero
    
    private let minScale: CGFloat = 0.1
    private let maxScale: CGFloat = 20
    
    var body: some View {
        GeometryReader { geo in
            let size = imageSize(in: geo.size)
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: dragStart.width + value.translation.width,
                                height: dragStart.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            dragStart = offset
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if scale > 1.01 {
                            scale = 1
                            offset = .zero
                            dragStart = .zero
                        } else {
                            scale = 2
                        }
                    }
                }
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            let newScale = scale * value.magnification
                            scale = min(max(minScale, newScale), maxScale)
                        }
                )
        }
    }
    
    private func imageSize(in container: CGSize) -> CGSize {
        let iw = image.size.width
        let ih = image.size.height
        let r = min(container.width / iw, container.height / ih)
        return CGSize(width: iw * r, height: ih * r)
    }
}
