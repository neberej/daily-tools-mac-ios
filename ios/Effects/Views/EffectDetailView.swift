//
//  EffectDetailView.swift
//  Effects
//

import CoreImage
import SwiftUI

struct EffectDetailView: View {
    let definition: EffectDefinition
    let sourceImage: UIImage
    let sourceCIImage: CIImage
    let onDismiss: () -> Void

    @State private var intensity: Double = 1.0
    @State private var filteredImage: UIImage?
    @State private var isExporting = false
    @State private var showExportSuccess = false
    @State private var exportError: String?
    @State private var renderTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            AppTheme.surfaceBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                detailTopBar

                Spacer(minLength: 0)

                filteredPreview

                Spacer(minLength: 0)

                controlsPanel
            }

            if showExportSuccess {
                successToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task {
            await renderPreview()
        }
        .onChange(of: intensity) { _, _ in
            debouncedRender()
        }
    }

    // MARK: - Top Bar

    private var detailTopBar: some View {
        HStack {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(definition.name)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Button {
                Task { await exportPhoto() }
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
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Preview

    private var filteredPreview: some View {
        Group {
            if let filteredImage {
                Image(uiImage: filteredImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                    )
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: 300)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Controls Panel

    private var controlsPanel: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Intensity")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))

                Spacer()

                if intensity > 0.01 {
                    Button {
                        intensity = 0
                    } label: {
                        Text("Reset")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }

                Text("\(Int(intensity * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 44, alignment: .trailing)
            }

            Slider(value: $intensity, in: definition.intensityRange, step: 0.01)
                .tint(.white)

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
                if pressing {
                    filteredImage = sourceImage
                } else {
                    Task { await renderPreview() }
                }
            }, perform: {})
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Success Toast

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

    // MARK: - Rendering (cancellable, no detach)

    private func debouncedRender() {
        renderTask?.cancel()
        renderTask = Task(priority: .userInitiated) {
            try? await Task.sleep(for: .milliseconds(80))
            try? Task.checkCancellation()

            await renderPreview()
        }
    }

    private func renderPreview() async {
        let def = definition
        let ci = sourceCIImage
        let inten = intensity

        let effect = def.make()
        let ciOut = EffectRenderer.apply(effect, to: ci, intensity: inten, target: .preview(maxDimension: 1200))

        do { try Task.checkCancellation() } catch { return }

        let ui = EffectRenderer.render(ciOut)

        do { try Task.checkCancellation() } catch { return }

        await MainActor.run {
            filteredImage = ui
        }
    }

    // MARK: - Export (same thread, no detach)

    private func exportPhoto() async {
        guard !isExporting else { return }
        isExporting = true
        exportError = nil

        let effect = definition.make()
        let ciOut = EffectRenderer.apply(effect, to: sourceCIImage, intensity: intensity, target: .fullRes)
        let fullImage = EffectRenderer.render(ciOut)

        guard let fullImage else {
            isExporting = false
            exportError = "Failed to render image"
            return
        }

        do {
            try await EffectsExporter.save(fullImage)
            withAnimation(.spring(duration: 0.4)) {
                showExportSuccess = true
            }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.spring(duration: 0.3)) {
                showExportSuccess = false
            }
        } catch {
            exportError = error.localizedDescription
        }

        isExporting = false
    }
}
