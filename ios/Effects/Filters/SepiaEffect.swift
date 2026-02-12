//
//  SepiaEffect.swift
//  Effects
//

import CoreImage

struct SepiaEffect: PhotoEffect {
    func apply(to image: CIImage, intensity: Double) -> CIImage {
        var result = image

        // Rich sepia tone
        if let sepia = CIFilter(name: "CISepiaTone") {
            sepia.setValue(result, forKey: kCIInputImageKey)
            sepia.setValue(0.85, forKey: kCIInputIntensityKey)
            result = sepia.outputImage ?? result
        }

        // Slight warmth and soft contrast
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(result, forKey: kCIInputImageKey)
            controls.setValue(1.05, forKey: kCIInputContrastKey)
            controls.setValue(0.03, forKey: kCIInputBrightnessKey)
            result = controls.outputImage ?? result
        }

        // Subtle vignette for period feel
        if let vignette = CIFilter(name: "CIVignette") {
            vignette.setValue(result, forKey: kCIInputImageKey)
            vignette.setValue(2.2, forKey: kCIInputRadiusKey)
            vignette.setValue(0.6, forKey: kCIInputIntensityKey)
            result = vignette.outputImage ?? result
        }

        return EffectCompositor.mix(original: image, filtered: result, amount: intensity)
    }
}
