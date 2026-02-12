//
//  BloomEffect.swift
//  Effects
//

import CoreImage

struct BloomEffect: PhotoEffect {
    func apply(to image: CIImage, intensity: Double) -> CIImage {
        var result = image

        // Soft glow on highlights (dreamy)
        if let bloom = CIFilter(name: "CIBloom") {
            bloom.setValue(result, forKey: kCIInputImageKey)
            bloom.setValue(15, forKey: kCIInputRadiusKey)
            bloom.setValue(0.9, forKey: kCIInputIntensityKey)
            result = bloom.outputImage ?? result
        }

        // Lift shadows slightly for airy look
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(result, forKey: kCIInputImageKey)
            controls.setValue(0.98, forKey: kCIInputContrastKey)
            controls.setValue(0.04, forKey: kCIInputBrightnessKey)
            controls.setValue(1.08, forKey: kCIInputSaturationKey)
            result = controls.outputImage ?? result
        }

        // Warm pastel tint
        if let temp = CIFilter(name: "CITemperatureAndTint") {
            temp.setValue(result, forKey: kCIInputImageKey)
            temp.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            temp.setValue(CIVector(x: 7500, y: 80), forKey: "inputTargetNeutral")
            result = temp.outputImage ?? result
        }

        return EffectCompositor.mix(original: image, filtered: result, amount: intensity)
    }
}
