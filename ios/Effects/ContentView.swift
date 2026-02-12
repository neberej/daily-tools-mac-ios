//
//  ContentView.swift
//  Effects
//

import Photos
import SwiftUI

struct EffectsContentView: View {
    /// Canonical source: CIImage (orientation applied once at pick).
    @State private var selectedCIImage: CIImage?
    /// Derived for display only (PhotoActionView, EditorView, compare in EffectDetail).
    @State private var displayImage: UIImage?
    @State private var currentFlow: Flow = .none
    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined

    private enum Flow {
        case none
        case action
        case edit
        case effects
    }

    var body: some View {
        ZStack {
            AppTheme.surfaceBackground.ignoresSafeArea()

            switch authorizationStatus {
            case .authorized, .limited:
                flowView
            case .denied, .restricted:
                deniedView
            default:
                landingView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentFlow == .none)
        .animation(.easeInOut(duration: 0.3), value: currentFlow == .action)
        .animation(.easeInOut(duration: 0.3), value: currentFlow == .edit)
        .animation(.easeInOut(duration: 0.3), value: currentFlow == .effects)
        .task {
            authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if authorizationStatus == .notDetermined {
                authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            }
        }
        .onChange(of: selectedCIImage) { _, newCI in
            if let ci = newCI {
                Task(priority: .userInitiated) {
                    let ui = EffectRenderer.render(ci)
                    await MainActor.run {
                        displayImage = ui
                        if selectedCIImage != nil {
                            withAnimation { currentFlow = .action }
                        }
                    }
                }
            } else {
                displayImage = nil
            }
        }
    }

    // MARK: - Flow Router

    @ViewBuilder
    private var flowView: some View {
        switch currentFlow {
        case .none:
            landingView
                .transition(.opacity)

        case .action:
            if let displayImage {
                PhotoActionView(
                    image: displayImage,
                    onSelect: { action in
                        withAnimation {
                            currentFlow = action == .edit ? .edit : .effects
                        }
                    },
                    onBack: {
                        resetToLanding()
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

        case .edit:
            if let displayImage {
                EditorView(
                    sourceImage: displayImage,
                    onDismiss: {
                        withAnimation { currentFlow = .action }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

        case .effects:
            if let selectedCIImage, let displayImage {
                EffectsBrowserView(
                    sourceImage: displayImage,
                    sourceCIImage: selectedCIImage,
                    onReset: {
                        withAnimation { currentFlow = .action }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    // MARK: - Landing

    private var landingView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Effects")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Edit photos & apply beautiful filters")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            PhotoPickerView(selectedCIImage: $selectedCIImage)

            Spacer()
        }
        // Transition to .action happens in onChange(selectedCIImage) after displayImage is derived
    }

    // MARK: - Denied

    private var deniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.white.opacity(0.5))

            Text("Photo Access Required")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("Please enable photo access in Settings to use Effects.")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(.white, in: Capsule())
        }
        .padding(32)
    }

    // MARK: - Helpers

    private func resetToLanding() {
        withAnimation {
            currentFlow = .none
            selectedCIImage = nil
            displayImage = nil
        }
    }
}
