//
//  PaintContentView.swift
//  Paint
//
//  Simple layout: left = tools, center = canvas, bottom = main toolbar (New, Open, Save).
//

import SwiftUI
import AppKit

struct PaintContentView: View {
    @StateObject private var viewModel = PaintViewModel()
    @State private var zoomScale: CGFloat = 1

    private let zoomMin: CGFloat = 0.25
    private let zoomMax: CGFloat = 4
    private let zoomStep: CGFloat = 1.25

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                toolStrip
                canvasArea(zoomScale: zoomScale)
                    .frame(minWidth: 400, minHeight: 300)
            }
            bottomToolbar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themedBackground(.primary)
        .onReceive(NotificationCenter.default.publisher(for: .paintNew)) { _ in viewModel.newCanvas() }
        .onReceive(NotificationCenter.default.publisher(for: .paintClear)) { _ in viewModel.clearCanvas() }
        .onReceive(NotificationCenter.default.publisher(for: .paintUndo)) { _ in viewModel.undo() }
    }

    private var toolStrip: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("Tools")
                .font(.system(size: AppTheme.FontSize.caption, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.Spacing.xs)
            LazyVGrid(columns: [GridItem(.fixed(28)), GridItem(.fixed(28))], spacing: AppTheme.Spacing.xxs) {
                ForEach(PaintTool.allCases) { tool in
                    Button {
                        viewModel.selectedTool = tool
                    } label: {
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 14))
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
                            .background(viewModel.selectedTool == tool ? Color.accentColor.opacity(0.3) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                    }
                    .buttonStyle(.plain)
                    .help(tool.rawValue)
                }
                Button(action: { viewModel.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14))
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                        .foregroundStyle(viewModel.canUndo ? Color.primary : Color.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canUndo)
                .help("Undo")
            }
            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.sm)
        .frame(width: 64)
        .background(AppTheme.secondaryBackground)
    }

    private func canvasArea(zoomScale: CGFloat) -> some View {
        let w = viewModel.canvasSize.width
        let h = viewModel.canvasSize.height
        return ScrollView([.horizontal, .vertical]) {
            PaintCanvasView(viewModel: viewModel)
                .frame(width: w, height: h)
                .scaleEffect(zoomScale)
                .frame(width: w * zoomScale, height: h * zoomScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.tertiaryBackground)
    }

    private var bottomToolbar: some View {
        AppBottomToolbar(
            new: { viewModel.newCanvas() },
            open: { viewModel.openImage() },
            save: { viewModel.saveImage() },
            trailing: {
                HStack(spacing: AppTheme.Spacing.md) {
                    Text(viewModel.documentDisplayName)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 100, alignment: .leading)
                        .help("Current document")
                    HStack(spacing: 2) {
                        Button(action: { zoomScale = max(zoomMin, zoomScale / zoomStep) }) {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .help("Zoom out")
                        Button(action: { zoomScale = min(zoomMax, zoomScale * zoomStep) }) {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .help("Zoom in")
                    }
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(width: 1, height: 18)
                    HStack(spacing: 8) {
                        ColorPicker("Line", selection: Binding(
                            get: { viewModel.foregroundColor },
                            set: { viewModel.setForeground($0) }
                        ))
                        .labelsHidden()
                        .frame(width: 28, height: 24)
                        .help("Line, text, brush color")
                        FillColorWell(fillColor: Binding(
                            get: { viewModel.fillColor },
                            set: { viewModel.fillColor = $0 }
                        ))
                        .frame(width: 36, height: 24)
                        .help("Fill color for shapes (clear for outline only)")
                    }
                }
            }
        )
    }
}

private struct FillColorWell: View {
    @Binding var fillColor: Color?

    var body: some View {
        Group {
            if let color = fillColor {
                HStack(spacing: 6) {
                    ColorPicker("Fill", selection: Binding(
                        get: { color },
                        set: { fillColor = $0 }
                    ))
                    .labelsHidden()
                    .frame(width: 22, height: 22)
                    Button {
                        fillColor = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("No fill")
                }
            } else {
                Button {
                    fillColor = .blue
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 22, height: 22)
                        Image(systemName: "slash.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help("No fill (tap to set fill color)")
            }
        }
        .frame(width: 36, height: 24)
    }
}

extension Notification.Name {
    static let paintNew = Notification.Name("Paint.New")
    static let paintClear = Notification.Name("Paint.Clear")
    static let paintUndo = Notification.Name("Paint.Undo")
    static let paintDidOpen = Notification.Name("Paint.DidOpen")
}
