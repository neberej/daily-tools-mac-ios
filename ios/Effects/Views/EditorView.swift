//
//  EditorView.swift
//  Effects
//

import SwiftUI

enum EditorTool: String, CaseIterable, Identifiable {
    case resize     = "Resize"
    case crop       = "Crop"
    case removeBg   = "Remove BG"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .resize:   return "arrow.up.left.and.arrow.down.right"
        case .crop:     return "crop"
        case .removeBg: return "person.crop.rectangle"
        }
    }
}

struct EditorView: View {
    let sourceImage: UIImage
    let onDismiss: () -> Void

    @State private var currentImage: UIImage
    @State private var selectedTool: EditorTool = .resize
    @State private var isExporting = false
    @State private var showExportSuccess = false

    init(sourceImage: UIImage, onDismiss: @escaping () -> Void) {
        self.sourceImage = sourceImage
        self.onDismiss = onDismiss
        _currentImage = State(initialValue: sourceImage)
    }

    var body: some View {
        ZStack {
            AppTheme.surfaceBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                toolContent
                toolPicker
            }

            if showExportSuccess {
                successToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Edit")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            // Save button
            Button {
                Task { await savePhoto() }
            } label: {
                Text("Save")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isExporting)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Tool Content

    private var toolContent: some View {
        Group {
            switch selectedTool {
            case .resize:
                ResizeToolView(image: $currentImage)
            case .crop:
                CropToolView(image: $currentImage)
            case .removeBg:
                RemoveBackgroundView(image: $currentImage)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tool Picker

    private var toolPicker: some View {
        HStack(spacing: 0) {
            ForEach(EditorTool.allCases) { tool in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTool = tool
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tool.icon)
                            .font(.system(size: 20, weight: .medium))
                        Text(tool.rawValue)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(selectedTool == tool ? .white : .white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Save

    private func savePhoto() async {
        guard !isExporting else { return }
        isExporting = true

        do {
            try await EffectsExporter.save(currentImage)
            withAnimation(.spring(duration: 0.4)) {
                showExportSuccess = true
            }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.spring(duration: 0.3)) {
                showExportSuccess = false
            }
        } catch {
            // silently fail for now
        }

        isExporting = false
    }

    // MARK: - Toast

    private var successToast: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Saved to Effects album")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.3), radius: 16, y: 4)
            .padding(.top, 60)

            Spacer()
        }
    }
}
