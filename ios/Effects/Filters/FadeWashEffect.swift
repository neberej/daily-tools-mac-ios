//
//  FadeWashEffect.swift
//  Effects
//

import CoreImage

struct FadeWashEffect: PhotoEffect {
    func apply(to image: CIImage, intensity: Double) -> CIImage {
        var result = image

        // Lifted blacks + reduced contrast (faded film)
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(result, forKey: kCIInputImageKey)
            controls.setValue(0.78, forKey: kCIInputContrastKey)
            controls.setValue(0.07, forKey: kCIInputBrightnessKey)
            controls.setValue(0.72, forKey: kCIInputSaturationKey)
            result = controls.outputImage ?? result
        }

        // Gamma for softer midtones
        if let gamma = CIFilter(name: "CIGammaAdjust") {
            gamma.setValue(result, forKey: kCIInputImageKey)
            gamma.setValue(1.12, forKey: "inputPower")
            result = gamma.outputImage ?? result
        }

        // Cool pastel wash (slight blue-magenta)
        if let matrix = CIFilter(name: "CIColorMatrix") {
            matrix.setValue(result, forKey: kCIInputImageKey)
            matrix.setValue(CIVector(x: 0.98, y: 0.02, z: 0, w: 0), forKey: "inputRVector")
            matrix.setValue(CIVector(x: 0.01, y: 0.97, z: 0.02, w: 0), forKey: "inputGVector")
            matrix.setValue(CIVector(x: 0.02, y: 0.01, z: 1, w: 0), forKey: "inputBVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            matrix.setValue(CIVector(x: 0.02, y: 0.03, z: 0.04, w: 0), forKey: "inputBiasVector")
            result = matrix.outputImage ?? result
        }

        return EffectCompositor.mix(original: image, filtered: result, amount: intensity)
    }
}
