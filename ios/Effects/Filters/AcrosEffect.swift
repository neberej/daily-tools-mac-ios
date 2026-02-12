//
//  AcrosEffect.swift
//  Effects
//

import CoreImage

/// Fujifilm Acros: fine-grain B&W with rich tonality and subtle highlight glow.
struct AcrosEffect: PhotoEffect {
    func apply(to image: CIImage, intensity: Double) -> CIImage {
        var result = image

        // Smooth B&W base
        if let mono = CIFilter(name: "CIPhotoEffectMono") {
            mono.setValue(result, forKey: kCIInputImageKey)
            result = mono.outputImage ?? result
        }

        // Rich tonality: moderate contrast, no crushed blacks
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(result, forKey: kCIInputImageKey)
            controls.setValue(1.2, forKey: kCIInputContrastKey)
            controls.setValue(0.02, forKey: kCIInputBrightnessKey)
            controls.setValue(0, forKey: kCIInputSaturationKey)
            result = controls.outputImage ?? result
        }

        // Slight highlight rolloff (Acros glow)
        if let gamma = CIFilter(name: "CIGammaAdjust") {
            gamma.setValue(result, forKey: kCIInputImageKey)
            gamma.setValue(0.96, forKey: "inputPower")
            result = gamma.outputImage ?? result
        }

        // Very subtle vignette
        if let vignette = CIFilter(name: "CIVignette") {
            vignette.setValue(result, forKey: kCIInputImageKey)
            vignette.setValue(2.5, forKey: kCIInputRadiusKey)
            vignette.setValue(0.4, forKey: kCIInputIntensityKey)
            result = vignette.outputImage ?? result
        }

        return EffectCompositor.mix(original: image, filtered: result, amount: intensity)
    }
}
