//
//  PhotoEffect.swift
//  Effects
//

import CoreImage
import UIKit

// MARK: - Category

enum EffectCategory: String, CaseIterable, Identifiable {
    case film     = "Film"
    case fujifilm = "Fujifilm"
    case light    = "Light"
    case color    = "Color"
    case texture  = "Texture"
    case mono     = "Mono"

    var id: String { rawValue }
}

// MARK: - Protocol (minimal, pure)

protocol PhotoEffect: Sendable {
    /// Apply effect to image. Intensity 0 = original, 1 = full effect. No side effects.
    func apply(to image: CIImage, intensity: Double) -> CIImage
}

// MARK: - Definition (metadata + lazy instantiation)

struct EffectDefinition: Identifiable, Sendable {
    let id: String
    let name: String
    let icon: String
    let category: EffectCategory
    let defaultIntensity: Double
    let intensityRange: ClosedRange<Double>
    let make: @Sendable () -> any PhotoEffect
}

// MARK: - Compositor (explicit mix, no protocol extension)

enum EffectCompositor {
    /// Blend filtered over original by amount (0 = original, 1 = full filtered).
    static func mix(original: CIImage, filtered: CIImage, amount: Double) -> CIImage {
        let t = max(0, min(1, amount))
        if t <= 0.001 { return original }
        if t >= 0.999 { return filtered.cropped(to: original.extent) }

        let fg = filtered.extent == original.extent ? filtered : filtered.cropped(to: original.extent)

        guard
            let matrix = CIFilter(name: "CIColorMatrix"),
            let over = CIFilter(name: "CISourceOverCompositing")
        else { return fg }

        matrix.setValue(fg, forKey: kCIInputImageKey)
        matrix.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
        matrix.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
        matrix.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
        matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputAVector")
        matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: CGFloat(t)), forKey: "inputBiasVector")

        guard let fgA = matrix.outputImage else { return fg }

        over.setValue(fgA, forKey: kCIInputImageKey)
        over.setValue(original, forKey: kCIInputBackgroundImageKey)

        return (over.outputImage ?? fg).cropped(to: original.extent)
    }
}

// MARK: - Render target (centralized sizing)

enum RenderTarget {
    case preview(maxDimension: CGFloat)
    case fullRes
}

// MARK: - Renderer (centralized apply + render)

enum EffectRenderer {
    static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Apply effect and return CIImage. Downscales for preview; crops to input extent.
    static func apply(
        _ effect: any PhotoEffect,
        to image: CIImage,
        intensity: Double,
        target: RenderTarget
    ) -> CIImage {
        let clamped = max(0, min(1, intensity))
        let base: CIImage
        switch target {
        case .fullRes:
            base = image
        case .preview(let maxDim):
            base = downscale(image, maxDim: maxDim)
        }
        let out = effect.apply(to: base, intensity: clamped)
        return out.extent == base.extent ? out : out.cropped(to: base.extent)
    }

    /// Render CIImage to UIImage. Thread-safe.
    static func render(_ ciImage: CIImage) -> UIImage? {
        guard let cg = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private static func downscale(_ image: CIImage, maxDim: CGFloat) -> CIImage {
        let w = image.extent.width, h = image.extent.height
        guard max(w, h) > maxDim else { return image }
        let scale = maxDim / max(w, h)
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }
}

// MARK: - Registry (data-only, lazy effects)

enum EffectRegistry {
    static let all: [EffectDefinition] = [
        .init(id: "vintage", name: "Vintage", icon: "camera.filters", category: .film, defaultIntensity: 1.0, intensityRange: 0...1, make: { VintageEffect() }),
        .init(id: "fadewash", name: "Fade", icon: "moon.haze", category: .film, defaultIntensity: 1.0, intensityRange: 0...1, make: { FadeWashEffect() }),
        .init(id: "sepia", name: "Sepia", icon: "photo.artframe", category: .film, defaultIntensity: 1.0, intensityRange: 0...1, make: { SepiaEffect() }),
        .init(id: "classicchrome", name: "Classic Chrome", icon: "camera.metering.center.weighted", category: .fujifilm, defaultIntensity: 1.0, intensityRange: 0...1, make: { ClassicChromeEffect() }),
        .init(id: "proneg", name: "Pro Neg", icon: "person.crop.rectangle", category: .fujifilm, defaultIntensity: 1.0, intensityRange: 0...1, make: { ProNegEffect() }),
        .init(id: "velvia", name: "Velvia", icon: "leaf.fill", category: .fujifilm, defaultIntensity: 1.0, intensityRange: 0...1, make: { VelviaEffect() }),
        .init(id: "acros", name: "Acros", icon: "circle.grid.cross", category: .fujifilm, defaultIntensity: 1.0, intensityRange: 0...1, make: { AcrosEffect() }),
        .init(id: "provia", name: "Provia", icon: "sun.max.fill", category: .fujifilm, defaultIntensity: 1.0, intensityRange: 0...1, make: { ProviaEffect() }),
        .init(id: "bloom", name: "Bloom", icon: "sparkles", category: .light, defaultIntensity: 1.0, intensityRange: 0...1, make: { BloomEffect() }),
        .init(id: "warmsunset", name: "Sunset", icon: "sun.max", category: .light, defaultIntensity: 1.0, intensityRange: 0...1, make: { WarmSunsetEffect() }),
        .init(id: "chrome", name: "Chrome", icon: "paintpalette", category: .color, defaultIntensity: 1.0, intensityRange: 0...1, make: { ChromeEffect() }),
        .init(id: "tonal", name: "Tonal", icon: "circle.grid.3x3", category: .color, defaultIntensity: 1.0, intensityRange: 0...1, make: { TonalEffect() }),
        .init(id: "grain", name: "Grain", icon: "aqi.medium", category: .texture, defaultIntensity: 1.0, intensityRange: 0...1, make: { GrainEffect() }),
        .init(id: "vignette", name: "Vignette", icon: "circle.dashed", category: .texture, defaultIntensity: 1.0, intensityRange: 0...1, make: { VignetteEffect() }),
        .init(id: "noir", name: "Noir", icon: "circle.lefthalf.filled", category: .mono, defaultIntensity: 1.0, intensityRange: 0...1, make: { NoirEffect() }),
    ]

    static func effects(for category: EffectCategory) -> [EffectDefinition] {
        all.filter { $0.category == category }
    }
}
