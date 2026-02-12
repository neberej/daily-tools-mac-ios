//
//  VintageEffect.swift
//  Effects
//

import CoreImage

struct VintageEffect: PhotoEffect {
    func apply(to image: CIImage, intensity: Double) -> CIImage {
        var result = image

        // Warm film base: lift shadows, soft contrast
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(result, forKey: kCIInputImageKey)
            controls.setValue(0.88, forKey: kCIInputContrastKey)
            controls.setValue(0.06, forKey: kCIInputBrightnessKey)
            controls.setValue(0.55, forKey: kCIInputSaturationKey)
            result = controls.outputImage ?? result
        }

        // Strong sepia wash
        if let sepia = CIFilter(name: "CISepiaTone") {
            sepia.setValue(result, forKey: kCIInputImageKey)
            sepia.setValue(0.45, forKey: kCIInputIntensityKey)
            result = sepia.outputImage ?? result
        }

        // Warm tint (orange-brown)
        if let tint = CIFilter(name: "CIColorMatrix") {
            tint.setValue(result, forKey: kCIInputImageKey)
            tint.setValue(CIVector(x: 1.05, y: 0, z: 0, w: 0), forKey: "inputRVector")
            tint.setValue(CIVector(x: 0, y: 0.95, z: 0, w: 0), forKey: "inputGVector")
            tint.setValue(CIVector(x: 0, y: 0, z: 0.82, w: 0), forKey: "inputBVector")
            tint.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            tint.setValue(CIVector(x: 0.02, y: 0.01, z: 0, w: 0), forKey: "inputBiasVector")
            result = tint.outputImage ?? result
        }

        // Film-style vignette
        if let vignette = CIFilter(name: "CIVignette") {
            vignette.setValue(result, forKey: kCIInputImageKey)
            vignette.setValue(1.8, forKey: kCIInputRadiusKey)
            vignette.setValue(1.2, forKey: kCIInputIntensityKey)
            result = vignette.outputImage ?? result
        }

        return EffectCompositor.mix(original: image, filtered: result, amount: intensity)
    }
}
