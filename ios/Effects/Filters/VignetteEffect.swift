//
//  VignetteEffect.swift
//  Effects
//

import CoreImage

struct VignetteEffect: PhotoEffect {
    func apply(to image: CIImage, intensity: Double) -> CIImage {
        var result = image

        // Strong dark-edge vignette
        if let vignette = CIFilter(name: "CIVignette") {
            vignette.setValue(result, forKey: kCIInputImageKey)
            vignette.setValue(2.5, forKey: kCIInputRadiusKey)
            vignette.setValue(1.8, forKey: kCIInputIntensityKey)
            result = vignette.outputImage ?? result
        }

        // Slight contrast boost so center pops
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(result, forKey: kCIInputImageKey)
            controls.setValue(1.06, forKey: kCIInputContrastKey)
            result = controls.outputImage ?? result
        }

        return EffectCompositor.mix(original: image, filtered: result, amount: intensity)
    }
}
