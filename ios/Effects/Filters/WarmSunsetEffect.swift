//
//  WarmSunsetEffect.swift
//  Effects
//

import CoreImage

struct WarmSunsetEffect: PhotoEffect {
    func apply(to image: CIImage, intensity: Double) -> CIImage {
        var result = image

        // Strong golden-hour temperature
        if let temp = CIFilter(name: "CITemperatureAndTint") {
            temp.setValue(result, forKey: kCIInputImageKey)
            temp.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            temp.setValue(CIVector(x: 8200, y: 120), forKey: "inputTargetNeutral")
            result = temp.outputImage ?? result
        }

        // Rich saturation + lift shadows
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(result, forKey: kCIInputImageKey)
            controls.setValue(1.2, forKey: kCIInputSaturationKey)
            controls.setValue(0.05, forKey: kCIInputBrightnessKey)
            controls.setValue(1.08, forKey: kCIInputContrastKey)
            result = controls.outputImage ?? result
        }

        // Warm vignette (darker edges)
        if let vignette = CIFilter(name: "CIVignette") {
            vignette.setValue(result, forKey: kCIInputImageKey)
            vignette.setValue(2.2, forKey: kCIInputRadiusKey)
            vignette.setValue(1.25, forKey: kCIInputIntensityKey)
            result = vignette.outputImage ?? result
        }

        // Orange-gold tint in midtones
        if let matrix = CIFilter(name: "CIColorMatrix") {
            matrix.setValue(result, forKey: kCIInputImageKey)
            matrix.setValue(CIVector(x: 1.08, y: 0.02, z: 0, w: 0), forKey: "inputRVector")
            matrix.setValue(CIVector(x: 0.02, y: 0.95, z: 0, w: 0), forKey: "inputGVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: 0.88, w: 0), forKey: "inputBVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            matrix.setValue(CIVector(x: 0.02, y: 0.01, z: -0.02, w: 0), forKey: "inputBiasVector")
            result = matrix.outputImage ?? result
        }

        return EffectCompositor.mix(original: image, filtered: result, amount: intensity)
    }
}
