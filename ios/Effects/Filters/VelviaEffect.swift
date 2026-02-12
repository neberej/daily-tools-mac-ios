//
//  VelviaEffect.swift
//  Effects
//

import CoreImage

/// Fujifilm Velvia: vivid saturation, strong greens and reds, punchy contrast.
struct VelviaEffect: PhotoEffect {
    func apply(to image: CIImage, intensity: Double) -> CIImage {
        var result = image

        // Punch saturation and contrast
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(result, forKey: kCIInputImageKey)
            controls.setValue(1.35, forKey: kCIInputSaturationKey)
            controls.setValue(1.18, forKey: kCIInputContrastKey)
            controls.setValue(0.02, forKey: kCIInputBrightnessKey)
            result = controls.outputImage ?? result
        }

        // Boost reds and greens (Velvia signature)
        if let matrix = CIFilter(name: "CIColorMatrix") {
            matrix.setValue(result, forKey: kCIInputImageKey)
            matrix.setValue(CIVector(x: 1.12, y: 0, z: 0, w: 0), forKey: "inputRVector")
            matrix.setValue(CIVector(x: 0, y: 1.1, z: 0, w: 0), forKey: "inputGVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: 0.98, w: 0), forKey: "inputBVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            matrix.setValue(CIVector(x: 0.02, y: 0, z: 0, w: 0), forKey: "inputBiasVector")
            result = matrix.outputImage ?? result
        }

        return EffectCompositor.mix(original: image, filtered: result, amount: intensity)
    }
}
