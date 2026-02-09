//
//  PaintCanvasView.swift
//  Paint
//
//  AppKit canvas: flipped view (top-left origin). Shape preview; no selection.
//

import SwiftUI
import AppKit

struct PaintCanvasView: NSViewRepresentable {
    @ObservedObject var viewModel: PaintViewModel

    func makeNSView(context: Context) -> PaintNSView {
        PaintNSView(viewModel: viewModel)
    }

    func updateNSView(_ nsView: PaintNSView, context: Context) {
        nsView.viewModel = viewModel
        nsView.needsDisplay = true
    }
}

private enum CanvasMode {
    case idle
    case previewing
}

final class PaintNSView: NSView {
    var viewModel: PaintViewModel?

    private var mode: CanvasMode = .idle
    private var previewShape: (tool: PaintTool, start: CGPoint, end: CGPoint)?
    private var textFieldHost: NSView?
    private var didOpenObserver: NSObjectProtocol?

    init(viewModel: PaintViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        wantsLayer = true
        didOpenObserver = NotificationCenter.default.addObserver(forName: .paintDidOpen, object: nil, queue: .main) { [weak self] _ in
            self?.clearOverlays()
        }
    }

    deinit {
        didOpenObserver.map { NotificationCenter.default.removeObserver($0) }
    }

    private func clearOverlays() {
        removeTextView()
        TextFieldDelegateOwner.shared.onCommit = nil
        previewShape = nil
        mode = .idle
        needsDisplay = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    /// Canvas view bounds match bitmap size (SwiftUI handles zoom via scaleEffect). No scaling here.
    private func viewPointToBitmap(_ point: CGPoint) -> CGPoint { point }
    private func bitmapPointToView(_ point: CGPoint) -> CGPoint { point }
    private func bitmapRectToView(_ rect: CGRect) -> CGRect { rect }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let vm = viewModel else { return }
        let rep = vm.bitmapRep
        rep.draw(
            in: bounds,
            from: NSRect(origin: .zero, size: rep.size),
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: true,
            hints: nil
        )
        if let preview = previewShape, let vm = viewModel {
            let startV = bitmapPointToView(preview.start)
            let endV = bitmapPointToView(preview.end)
            let rectV = CGRect(
                x: min(startV.x, endV.x),
                y: min(startV.y, endV.y),
                width: abs(endV.x - startV.x),
                height: abs(endV.y - startV.y)
            )
            guard let ctx = NSGraphicsContext.current?.cgContext else { return }
            ctx.saveGState()
            ctx.setShouldAntialias(true)
            ctx.setStrokeColor(vm.foregroundNSColor.cgColor)
            ctx.setLineWidth(max(1, vm.lineWidth))
            ctx.setLineDash(phase: 0, lengths: [6, 3])
            switch preview.tool {
            case .line:
                ctx.move(to: startV)
                ctx.addLine(to: endV)
                ctx.strokePath()
            case .rectangle:
                if let fill = vm.fillNSColor {
                    ctx.setFillColor(fill.cgColor)
                    ctx.fill(rectV)
                }
                ctx.setStrokeColor(vm.foregroundNSColor.cgColor)
                ctx.setLineWidth(max(1, vm.lineWidth))
                ctx.stroke(rectV)
            case .ellipse:
                if let fill = vm.fillNSColor {
                    ctx.setFillColor(fill.cgColor)
                    ctx.fillEllipse(in: rectV)
                }
                ctx.setStrokeColor(vm.foregroundNSColor.cgColor)
                ctx.setLineWidth(max(1, vm.lineWidth))
                ctx.strokeEllipse(in: rectV)
            default:
                ctx.strokePath()
            }
            ctx.restoreGState()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let vm = viewModel else { return }
        let point = convert(event.locationInWindow, from: nil)
        let p = viewPointToBitmap(point)

        if let host = textFieldHost, !host.frame.contains(point) {
            commitTextIfNeeded()
        }

        switch vm.selectedTool {
        case .fill:
            vm.fillAt(point: p)
        case .brush, .eraser, .airbrush:
            vm.startStroke(at: p)
        case .line, .rectangle, .ellipse:
            if vm.selectedTool.hasShapePreview {
                mode = .previewing
                previewShape = (vm.selectedTool, p, p)
            }
        case .text:
            commitTextIfNeeded()
            addTextView(at: point)
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let vm = viewModel else { return }
        let point = convert(event.locationInWindow, from: nil)
        let p = viewPointToBitmap(point)

        switch mode {
        case .previewing:
            if let prev = previewShape {
                previewShape = (prev.tool, prev.start, p)
            }
        case .idle:
            switch vm.selectedTool {
            case .brush, .eraser, .airbrush:
                vm.continueStroke(at: p)
            default:
                break
            }
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let vm = viewModel else { return }

        if let preview = previewShape {
            switch preview.tool {
            case .line:
                vm.drawShapeLine(from: preview.start, to: preview.end)
            case .rectangle:
                vm.drawShapeRectangle(from: preview.start, to: preview.end)
            case .ellipse:
                vm.drawShapeEllipse(from: preview.start, to: preview.end)
            default:
                break
            }
            previewShape = nil
            mode = .idle
        }
        vm.endStroke()
        needsDisplay = true
    }

    // MARK: - Text overlay

    private func addTextView(at viewPoint: CGPoint) {
        guard let vm = viewModel else { return }
        let field = NSTextView(frame: CGRect(x: viewPoint.x, y: viewPoint.y - 24, width: 200, height: 28))
        field.font = .systemFont(ofSize: 24)
        field.drawsBackground = false
        field.textColor = vm.foregroundNSColor
        field.isEditable = true
        field.isSelectable = true
        field.delegate = TextFieldDelegateOwner.shared
        TextFieldDelegateOwner.shared.onCommit = { [weak self] string in
            guard let self = self, let vm = self.viewModel else { return }
            let p = self.viewPointToBitmap(viewPoint)
            vm.drawText(string, at: p)
            self.removeTextView()
        }
        addSubview(field)
        textFieldHost = field
        window?.makeFirstResponder(field)
    }

    private func removeTextView() {
        textFieldHost?.removeFromSuperview()
        textFieldHost = nil
        TextFieldDelegateOwner.shared.onCommit = nil
        needsDisplay = true
    }

    private func commitTextIfNeeded() {
        guard textFieldHost != nil else { return }
        TextFieldDelegateOwner.shared.commit()
    }
}

private final class TextFieldDelegateOwner: NSObject, NSTextViewDelegate {
    static let shared = TextFieldDelegateOwner()
    var onCommit: ((String) -> Void)?

    func textDidChange(_ notification: Notification) {}

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            commit()
            return true
        }
        return false
    }

    func commit() {
        guard let field = NSApp.keyWindow?.firstResponder as? NSTextView,
              let owner = onCommit else { return }
        owner(field.string)
    }
}
