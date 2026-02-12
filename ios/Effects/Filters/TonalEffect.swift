//
//  TonalEffect.swift
//  Effects
//

import CoreImage

struct TonalEffect: PhotoEffect {
    func apply(to image: CIImage, intensity: Double) -> CIImage {
        var result = image

        // Posterized / reduced tonal range
        if let tonal = CIFilter(name: "CIPhotoEffectTonal") {
            tonal.setValue(result, forKey: kCIInputImageKey)
            result = tonal.outputImage ?? result
        }

        // Stronger contrast for graphic look
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(result, forKey: kCIInputImageKey)
            controls.setValue(1.2, forKey: kCIInputContrastKey)
            controls.setValue(0.9, forKey: kCIInputSaturationKey)
            controls.setValue(0.02, forKey: kCIInputBrightnessKey)
            result = controls.outputImage ?? result
        }

        // Slight warm split-tone
        if let matrix = CIFilter(name: "CIColorMatrix") {
            matrix.setValue(result, forKey: kCIInputImageKey)
            matrix.setValue(CIVector(x: 1.02, y: 0, z: 0, w: 0), forKey: "inputRVector")
            matrix.setValue(CIVector(x: 0, y: 0.98, z: 0, w: 0), forKey: "inputGVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: 0.94, w: 0), forKey: "inputBVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            matrix.setValue(CIVector(x: 0.01, y: 0.01, z: 0, w: 0), forKey: "inputBiasVector")
            result = matrix.outputImage ?? result
        }

        return EffectCompositor.mix(original: image, filtered: result, amount: intensity)
    }
}
