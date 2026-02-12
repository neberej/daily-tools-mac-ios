//
//  GrainEffect.swift
//  Effects
//

import CoreImage

struct GrainEffect: PhotoEffect {
    func apply(to image: CIImage, intensity: Double) -> CIImage {
        var result = image

        guard let noise = CIFilter(name: "CIRandomGenerator") else {
            return EffectCompositor.mix(original: image, filtered: result, amount: intensity)
        }
        var noiseImage = noise.outputImage ?? CIImage()
        noiseImage = noiseImage.cropped(to: image.extent)

        // Monochrome grain, mid-gray base
        if let mono = CIFilter(name: "CIColorControls") {
            mono.setValue(noiseImage, forKey: kCIInputImageKey)
            mono.setValue(0, forKey: kCIInputSaturationKey)
            mono.setValue(-0.35, forKey: kCIInputBrightnessKey)
            noiseImage = mono.outputImage ?? noiseImage
        }

        // Scale grain down then up for finer texture
        let scale = 0.25
        let scaled = noiseImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let scaledBack = scaled.transformed(by: CGAffineTransform(scaleX: 1/scale, y: 1/scale))
            .cropped(to: image.extent)

        // Soft light blend for film grain
        if let composite = CIFilter(name: "CISoftLightBlendMode") {
            composite.setValue(scaledBack, forKey: kCIInputImageKey)
            composite.setValue(result, forKey: kCIInputBackgroundImageKey)
            result = composite.outputImage ?? result
        }

        // Slight desaturation for film look
        if let desat = CIFilter(name: "CIColorControls") {
            desat.setValue(result, forKey: kCIInputImageKey)
            desat.setValue(0.92, forKey: kCIInputSaturationKey)
            result = desat.outputImage ?? result
        }

        return EffectCompositor.mix(original: image, filtered: result, amount: intensity)
    }
}
