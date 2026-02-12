//
//  EffectPreviewCard.swift
//  Effects
//

import CoreImage
import SwiftUI

struct EffectPreviewCard: View {
    let definition: EffectDefinition
    let sourceImage: CIImage
    let isSelected: Bool
    let action: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(ProgressView().tint(.white.opacity(0.3)))
                    }
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.white : Color.white.opacity(0.15),
                            lineWidth: isSelected ? 2 : 0.5
                        )
                )
                .shadow(color: isSelected ? .white.opacity(0.15) : .clear, radius: 8)

                Text(definition.name)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
        .task(id: definition.id) {
            await renderThumbnail()
        }
    }

    private func renderThumbnail() async {
        let effect = definition.make()
        let ciOut = EffectRenderer.apply(effect, to: sourceImage, intensity: 1.0, target: .preview(maxDimension: 200))
        let ui = EffectRenderer.render(ciOut)
        await MainActor.run {
            thumbnail = ui
        }
    }
}
