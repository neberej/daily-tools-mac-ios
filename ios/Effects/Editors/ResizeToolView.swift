//
//  ResizeToolView.swift
//  Effects
//

import SwiftUI

struct ResizeToolView: View {
    @Binding var image: UIImage

    @State private var targetWidth: String = ""
    @State private var targetHeight: String = ""
    @State private var lockAspectRatio: Bool = true
    @State private var lastEditedField: Field = .width

    private enum Field { case width, height }

    private var aspectRatio: CGFloat {
        guard image.size.height > 0 else { return 1 }
        return image.size.width / image.size.height
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Preview
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                )
                .padding(.horizontal, 24)

            Spacer()

            // Controls
            VStack(spacing: 16) {
                // Current dimensions
                Text("Current: \(Int(image.size.width)) × \(Int(image.size.height))")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                // Input row
                HStack(spacing: 12) {
                    dimensionField(label: "W", text: $targetWidth, field: .width)

                    // Lock toggle
                    Button {
                        lockAspectRatio.toggle()
                    } label: {
                        Image(systemName: lockAspectRatio ? "lock.fill" : "lock.open")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(lockAspectRatio ? .white : .white.opacity(0.4))
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)

                    dimensionField(label: "H", text: $targetHeight, field: .height)
                }

                // Preset buttons
                HStack(spacing: 10) {
                    presetButton("50%", scale: 0.5)
                    presetButton("75%", scale: 0.75)
                    presetButton("150%", scale: 1.5)
                    presetButton("2×", scale: 2.0)
                }

                // Apply button
                Button {
                    applyResize()
                } label: {
                    Text("Apply Resize")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
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
        .onAppear {
            targetWidth = "\(Int(image.size.width))"
            targetHeight = "\(Int(image.size.height))"
        }
    }

    // MARK: - Dimension Field

    private func dimensionField(label: String, text: Binding<String>, field: Field) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

            TextField("", text: text)
                .keyboardType(.numberPad)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .onChange(of: text.wrappedValue) { _, newVal in
                    guard lockAspectRatio, let val = Double(newVal), val > 0 else { return }
                    if field == .width {
                        lastEditedField = .width
                        targetHeight = "\(Int(val / aspectRatio))"
                    } else {
                        lastEditedField = .height
                        targetWidth = "\(Int(val * aspectRatio))"
                    }
                }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Preset

    private func presetButton(_ label: String, scale: CGFloat) -> some View {
        Button {
            let w = Int(image.size.width * scale)
            let h = Int(image.size.height * scale)
            targetWidth = "\(w)"
            targetHeight = "\(h)"
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Apply

    private func applyResize() {
        guard let w = Int(targetWidth), let h = Int(targetHeight), w > 0, h > 0 else { return }
        let targetSize = CGSize(width: w, height: h)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        image = resized
    }
}
