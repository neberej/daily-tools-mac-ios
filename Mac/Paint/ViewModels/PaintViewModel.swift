//
//  PaintViewModel.swift
//  Paint
//
//  Canvas bitmap, tool state, colors, undo, and drawing commands.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

private enum PaintCanvasDefaults {
    static let width = 800
    static let height = 600
}

@MainActor
final class PaintViewModel: ObservableObject {
    static let defaultCanvasWidth = PaintCanvasDefaults.width
    static let defaultCanvasHeight = PaintCanvasDefaults.height

    @Published var selectedTool: PaintTool = .brush
    @Published var foregroundColor: Color = .black
    @Published var fillColor: Color? = nil
    @Published var backgroundColor: Color = .white
    @Published var lineWidth: CGFloat = 2
    @Published var documentName: String = "untitled"
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    /// Bump to trigger canvas redraw via SwiftUI updateNSView (no notification loop).
    @Published private(set) var displayVersion: Int = 0

    private var bitmap: NSBitmapImageRep
    private var documentFileURL: URL?
    private var undoStack: [NSImage] = []
    private let maxUndo = 32
    private var lastDrawPoint: CGPoint?

    var canvasSize: CGSize { CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh) }

    /// Display in toolbar: "untitled" when new, or filename with extension when opened (e.g. "brush.png").
    var documentDisplayName: String {
        documentFileURL?.lastPathComponent ?? documentName
    }

    /// Exposed for AppKit canvas to draw directly; no NSImage recreation.
    var bitmapRep: NSBitmapImageRep { bitmap }

    private func refreshDisplay() {
        displayVersion += 1
    }

    init() {
        self.bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Self.defaultCanvasWidth,
            pixelsHigh: Self.defaultCanvasHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        bitmap.size = CGSize(width: Self.defaultCanvasWidth, height: Self.defaultCanvasHeight)
        clearCanvasToWhite()
        pushUndo()
        refreshDisplay()
    }

    private func nsColor(_ c: Color) -> NSColor {
        NSColor(c)
    }

    /// For overlay drawing (e.g. shape preview) in AppKit.
    var foregroundNSColor: NSColor { nsColor(foregroundColor) }
    /// Fill color for shapes and fill tool; nil = no fill.
    var fillNSColor: NSColor? { fillColor.map { nsColor($0) } }

    private func clearCanvasToWhite() {
        guard let ctx = NSGraphicsContext(bitmapImageRep: bitmap) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        nsColor(backgroundColor).setFill()
        ctx.cgContext.fill(CGRect(origin: .zero, size: bitmap.size))
        NSGraphicsContext.restoreGraphicsState()
    }

    func newCanvas(width: Int = PaintCanvasDefaults.width, height: Int = PaintCanvasDefaults.height) {
        bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        bitmap.size = CGSize(width: width, height: height)
        clearCanvasToWhite()
        undoStack.removeAll()
        pushUndo()
        refreshDisplay()
        documentName = "untitled"
        documentFileURL = nil
        NotificationCenter.default.post(name: .paintDidOpen, object: nil)
    }

    func clearCanvas() {
        clearCanvasToWhite()
        pushUndo()
        refreshDisplay()
    }

    private func pushUndo() {
        let copy = NSImage(size: bitmap.size)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: bitmap.pixelsWide, pixelsHigh: bitmap.pixelsHigh, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = bitmap.size
        if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = ctx
            bitmap.draw(in: NSRect(origin: .zero, size: bitmap.size))
            NSGraphicsContext.restoreGraphicsState()
        }
        copy.addRepresentation(rep)
        undoStack.append(copy)
        if undoStack.count > maxUndo { undoStack.removeFirst() }
        canUndo = undoStack.count > 1
        canRedo = false
    }

    func undo() {
        guard undoStack.count > 1 else { return }
        undoStack.removeLast()
        if let prev = undoStack.last, let rep = prev.representations.first as? NSBitmapImageRep {
            bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: rep.pixelsWide, pixelsHigh: rep.pixelsHigh, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            bitmap.size = rep.size
            if let ctx = NSGraphicsContext(bitmapImageRep: bitmap) {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = ctx
                rep.draw(in: NSRect(origin: .zero, size: rep.size))
                NSGraphicsContext.restoreGraphicsState()
            }
            refreshDisplay()
        }
        canUndo = undoStack.count > 1
        canRedo = true
    }

    func redo() {
        // Simplified: we don't keep a redo stack for this first version
        canRedo = false
    }

    func startStroke(at point: CGPoint) {
        lastDrawPoint = point
        if selectedTool == .brush || selectedTool == .eraser || selectedTool == .airbrush {
            pushUndo()
        }
        switch selectedTool {
        case .airbrush:
            drawAirbrush(at: point)
        default:
            drawAt(point)
        }
    }

    func continueStroke(at point: CGPoint) {
        guard let last = lastDrawPoint else { lastDrawPoint = point; drawAt(point); return }
        switch selectedTool {
        case .brush, .eraser:
            drawLine(from: last, to: point)
        case .airbrush:
            drawAirbrush(at: point)
        default:
            break
        }
        lastDrawPoint = point
    }

    func endStroke() {
        lastDrawPoint = nil
    }

    /// One flip: context (0,0) = top-left so view points match. No double conversion.
    private func withContext(_ draw: (CGContext) -> Void) {
        guard let ctx = NSGraphicsContext(bitmapImageRep: bitmap) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        let cg = ctx.cgContext
        cg.translateBy(x: 0, y: bitmap.size.height)
        cg.scaleBy(x: 1, y: -1)
        cg.setShouldSmoothFonts(true)
        cg.setShouldAntialias(true)
        draw(cg)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawAt(_ point: CGPoint) {
        let color: NSColor = selectedTool == .eraser ? .white : nsColor(foregroundColor)
        withContext { cg in
            cg.setStrokeColor(color.cgColor)
            cg.setFillColor(color.cgColor)
            cg.setLineWidth(max(1, lineWidth))
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            let r = max(0.5, lineWidth / 2)
            cg.addEllipse(in: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
            cg.fillPath()
        }
        refreshDisplay()
    }

    private func drawLine(from p0: CGPoint, to p1: CGPoint) {
        let color: NSColor = selectedTool == .eraser ? .white : nsColor(foregroundColor)
        withContext { cg in
            cg.setStrokeColor(color.cgColor)
            cg.setLineWidth(max(1, lineWidth))
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            cg.move(to: p0)
            cg.addLine(to: p1)
            cg.strokePath()
        }
        refreshDisplay()
    }

    /// Airbrush: spray of small dots within radius for graffiti-style effect.
    private func drawAirbrush(at point: CGPoint) {
        let color: NSColor = selectedTool == .eraser ? .white : nsColor(foregroundColor)
        let radius = max(8, lineWidth * 6)
        let dotCount = 12
        withContext { cg in
            cg.setFillColor(color.cgColor)
            for _ in 0..<dotCount {
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let r = CGFloat.random(in: 0...1) * radius
                let dx = r * cos(angle)
                let dy = r * sin(angle)
                let dotSize = CGFloat.random(in: 0.5...(lineWidth * 1.5))
                let rect = CGRect(x: point.x + dx - dotSize/2, y: point.y + dy - dotSize/2, width: dotSize, height: dotSize)
                cg.fillEllipse(in: rect)
            }
        }
        refreshDisplay()
    }

    func drawShapeLine(from start: CGPoint, to end: CGPoint) {
        pushUndo()
        withContext { cg in
            cg.setStrokeColor(foregroundNSColor.cgColor)
            cg.setLineWidth(max(1, lineWidth))
            cg.setLineCap(.round)
            cg.move(to: start)
            cg.addLine(to: end)
            cg.strokePath()
        }
        refreshDisplay()
    }

    func drawShapeRectangle(from start: CGPoint, to end: CGPoint) {
        pushUndo()
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                          width: abs(end.x - start.x), height: abs(end.y - start.y))
        withContext { cg in
            if let fill = fillNSColor {
                cg.setFillColor(fill.cgColor)
                cg.fill(rect)
            }
            cg.setStrokeColor(foregroundNSColor.cgColor)
            cg.setLineWidth(max(1, lineWidth))
            cg.stroke(rect)
        }
        refreshDisplay()
    }

    func drawShapeEllipse(from start: CGPoint, to end: CGPoint) {
        pushUndo()
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                          width: abs(end.x - start.x), height: abs(end.y - start.y))
        withContext { cg in
            if let fill = fillNSColor {
                cg.setFillColor(fill.cgColor)
                cg.fillEllipse(in: rect)
            }
            cg.setStrokeColor(foregroundNSColor.cgColor)
            cg.setLineWidth(max(1, lineWidth))
            cg.strokeEllipse(in: rect)
        }
        refreshDisplay()
    }

    func fillAt(point: CGPoint) {
        guard let fillNSColor = fillNSColor else { return }
        let x = Int(point.x)
        let y = Int(point.y)
        guard x >= 0, x < bitmap.pixelsWide, y >= 0, y < bitmap.pixelsHigh else { return }
        let bitmapY = bitmap.pixelsHigh - 1 - y
        guard let targetColor = bitmap.colorAt(x: x, y: bitmapY) else { return }
        let fillNS = fillNSColor.usingColorSpace(.deviceRGB)!
        if targetColor.isEqual(fillNS) { return }
        pushUndo()
        guard let ptr = bitmap.bitmapData else { return }
        let bpp = bitmap.bitsPerPixel / 8
        let bpr = bitmap.bytesPerRow
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        let targetR = UInt8(targetColor.redComponent * 255)
        let targetG = UInt8(targetColor.greenComponent * 255)
        let targetB = UInt8(targetColor.blueComponent * 255)
        let targetA = UInt8(targetColor.alphaComponent * 255)
        let fillR = UInt8(fillNS.redComponent * 255)
        let fillG = UInt8(fillNS.greenComponent * 255)
        let fillB = UInt8(fillNS.blueComponent * 255)
        let fillA = UInt8(fillNS.alphaComponent * 255)
        let seedOffset = bitmapY * bpr + x * bpp
        let (b0, b1, b2, b3) = (ptr[seedOffset], ptr[seedOffset + 1], ptr[seedOffset + 2], ptr[seedOffset + 3])
        let isBGRA: Bool = (b0 == targetB && b1 == targetG && b2 == targetR && b3 == targetA)
        func getRGBA(px: Int, py: Int) -> (UInt8, UInt8, UInt8, UInt8) {
            let o = py * bpr + px * bpp
            if isBGRA {
                return (ptr[o + 2], ptr[o + 1], ptr[o], ptr[o + 3])
            }
            return (ptr[o], ptr[o + 1], ptr[o + 2], ptr[o + 3])
        }
        func setRGBA(px: Int, py: Int, r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
            let o = py * bpr + px * bpp
            if isBGRA {
                ptr[o] = b
                ptr[o + 1] = g
                ptr[o + 2] = r
                ptr[o + 3] = a
            } else {
                ptr[o] = r
                ptr[o + 1] = g
                ptr[o + 2] = b
                ptr[o + 3] = a
            }
        }
        let targetRGBA = (targetR, targetG, targetB, targetA)
        var stack = [(x, bitmapY)]
        var seen = Set<Int>(minimumCapacity: 4096)
        while let (cx, cy) = stack.popLast() {
            let key = cx + cy * width
            if seen.contains(key) { continue }
            seen.insert(key)
            let current = getRGBA(px: cx, py: cy)
            if current.0 == targetRGBA.0, current.1 == targetRGBA.1, current.2 == targetRGBA.2, current.3 == targetRGBA.3 {
                setRGBA(px: cx, py: cy, r: fillR, g: fillG, b: fillB, a: fillA)
                if cx + 1 < width { stack.append((cx + 1, cy)) }
                if cx - 1 >= 0 { stack.append((cx - 1, cy)) }
                if cy + 1 < height { stack.append((cx, cy + 1)) }
                if cy - 1 >= 0 { stack.append((cx, cy - 1)) }
            }
        }
        refreshDisplay()
    }

    func pickColor(at point: CGPoint) -> Color? {
        let x = Int(point.x)
        let y = Int(point.y)
        guard x >= 0, x < bitmap.pixelsWide, y >= 0, y < bitmap.pixelsHigh else { return nil }
        let by = bitmap.pixelsHigh - 1 - y
        guard let c = bitmap.colorAt(x: x, y: by) else { return nil }
        return Color(nsColor: c)
    }

    func setForeground(_ color: Color) {
        foregroundColor = color
    }

    func setBackground(_ color: Color) {
        backgroundColor = color
    }

    func saveImage() {
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else { return }
        if let url = documentFileURL {
            try? pngData.write(to: url, options: .atomic)
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(documentName).png"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self = self else { return }
            try? pngData.write(to: url, options: .atomic)
            self.documentFileURL = url
            self.documentName = url.deletingPathExtension().lastPathComponent
        }
    }

    func openImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff]
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self = self else { return }
            NotificationCenter.default.post(name: .paintDidOpen, object: nil)
            guard let image = NSImage(contentsOf: url) else { return }
            let size = image.size
            let w = Int(size.width)
            let h = Int(size.height)
            guard w > 0, h > 0 else { return }
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: w,
                pixelsHigh: h,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )!
            rep.size = size
            guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = ctx
            let cg = ctx.cgContext
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: 1, y: -1)
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: 1, y: -1)
            image.draw(in: CGRect(origin: .zero, size: size))
            NSGraphicsContext.restoreGraphicsState()
            self.bitmap = rep
            self.documentFileURL = url
            self.documentName = url.deletingPathExtension().lastPathComponent
            self.undoStack.removeAll()
            self.pushUndo()
            self.refreshDisplay()
            NotificationCenter.default.post(name: .paintDidOpen, object: nil)
        }
    }

    func drawText(_ string: String, at point: CGPoint, font: NSFont = .systemFont(ofSize: 24)) {
        pushUndo()
        let textColor = foregroundNSColor.usingColorSpace(.deviceRGB) ?? foregroundNSColor
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        let baselineY = point.y + font.ascender
        withContext { cg in
            cg.setFillColor(textColor.cgColor)
            (string as NSString).draw(at: CGPoint(x: point.x, y: baselineY), withAttributes: attrs)
        }
        refreshDisplay()
    }

    // MARK: - Palette for color selector
    static let paletteColors: [Color] = [
        .black, Color(white: 0.25), Color(white: 0.5), Color(white: 0.75), .white,
        .red, Color(red: 1, green: 0.5, blue: 0), .yellow, Color(red: 0.5, green: 0.75, blue: 0),
        Color(red: 0, green: 0.5, blue: 0), .cyan, .blue, Color(red: 0.5, green: 0, blue: 0.5),
        Color(red: 0.75, green: 0.5, blue: 0.75), Color(red: 0.5, green: 0.25, blue: 0),
        Color(red: 0.75, green: 0.75, blue: 0.5), Color(red: 0.5, green: 0.5, blue: 0.5),
        Color(red: 0.75, green: 0.5, blue: 0.25), Color(red: 0.25, green: 0.5, blue: 0.25),
        Color(red: 0.25, green: 0.25, blue: 0.75), Color(red: 0.75, green: 0.25, blue: 0.25),
        Color(red: 0.25, green: 0.25, blue: 0.25), Color(red: 0.75, green: 0.75, blue: 0.75),
        Color(red: 1, green: 0.75, blue: 0.8), Color(red: 1, green: 0.85, blue: 0.7), Color(red: 1, green: 1, blue: 0.8),
        Color(red: 0.8, green: 1, blue: 0.8), Color(red: 0.8, green: 1, blue: 1), Color(red: 0.8, green: 0.9, blue: 1),
    ]
}
