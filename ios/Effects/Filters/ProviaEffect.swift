//
//  ProviaEffect.swift
//  Effects
//

import CoreImage

/// Fujifilm Provia: balanced, natural — standard slide film look with mild punch.
struct ProviaEffect: PhotoEffect {
    func apply(to image: CIImage, intensity: Double) -> CIImage {
        var result = image

        // Balanced contrast and saturation
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(result, forKey: kCIInputImageKey)
            controls.setValue(1.08, forKey: kCIInputContrastKey)
            controls.setValue(0.01, forKey: kCIInputBrightnessKey)
            controls.setValue(1.1, forKey: kCIInputSaturationKey)
            result = controls.outputImage ?? result
        }

        // Neutral, slight warmth
        if let temp = CIFilter(name: "CITemperatureAndTint") {
            temp.setValue(result, forKey: kCIInputImageKey)
            temp.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            temp.setValue(CIVector(x: 6600, y: 15), forKey: "inputTargetNeutral")
            result = temp.outputImage ?? result
        }

        return EffectCompositor.mix(original: image, filtered: result, amount: intensity)
    }
}
