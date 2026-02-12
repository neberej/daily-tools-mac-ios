//
//  ProNegEffect.swift
//  Effects
//

import CoreImage

/// Fujifilm Pro Neg: soft, flatter contrast — natural skin tones, gentle gradation.
struct ProNegEffect: PhotoEffect {
    func apply(to image: CIImage, intensity: Double) -> CIImage {
        var result = image

        // Soft contrast, neutral saturation
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(result, forKey: kCIInputImageKey)
            controls.setValue(0.9, forKey: kCIInputContrastKey)
            controls.setValue(0.03, forKey: kCIInputBrightnessKey)
            controls.setValue(0.95, forKey: kCIInputSaturationKey)
            result = controls.outputImage ?? result
        }

        // Gentle warmth (skin-friendly)
        if let temp = CIFilter(name: "CITemperatureAndTint") {
            temp.setValue(result, forKey: kCIInputImageKey)
            temp.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            temp.setValue(CIVector(x: 6800, y: 25), forKey: "inputTargetNeutral")
            result = temp.outputImage ?? result
        }

        // Slight highlight rolloff
        if let gamma = CIFilter(name: "CIGammaAdjust") {
            gamma.setValue(result, forKey: kCIInputImageKey)
            gamma.setValue(1.05, forKey: "inputPower")
            result = gamma.outputImage ?? result
        }

        return EffectCompositor.mix(original: image, filtered: result, amount: intensity)
    }
}
