//
//  ClassicChromeEffect.swift
//  Effects
//

import CoreImage

/// Fujifilm Classic Chrome: muted, documentary look — reduced saturation, lifted shadows, teal/green shift.
struct ClassicChromeEffect: PhotoEffect {
    func apply(to image: CIImage, intensity: Double) -> CIImage {
        var result = image

        // Reduce saturation, soften contrast
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(result, forKey: kCIInputImageKey)
            controls.setValue(0.72, forKey: kCIInputSaturationKey)
            controls.setValue(0.92, forKey: kCIInputContrastKey)
            controls.setValue(0.04, forKey: kCIInputBrightnessKey)
            result = controls.outputImage ?? result
        }

        // Muted greens/teals (pull cyan, reduce green pop)
        if let matrix = CIFilter(name: "CIColorMatrix") {
            matrix.setValue(result, forKey: kCIInputImageKey)
            matrix.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
            matrix.setValue(CIVector(x: 0.02, y: 0.92, z: 0.06, w: 0), forKey: "inputGVector")
            matrix.setValue(CIVector(x: 0, y: 0.04, z: 0.96, w: 0), forKey: "inputBVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBiasVector")
            result = matrix.outputImage ?? result
        }

        // Slight warm in shadows (lift + tint)
        if let gamma = CIFilter(name: "CIGammaAdjust") {
            gamma.setValue(result, forKey: kCIInputImageKey)
            gamma.setValue(1.08, forKey: "inputPower")
            result = gamma.outputImage ?? result
        }

        return EffectCompositor.mix(original: image, filtered: result, amount: intensity)
    }
}
