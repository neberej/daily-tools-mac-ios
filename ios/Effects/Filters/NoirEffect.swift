//
//  NoirEffect.swift
//  Effects
//

import CoreImage

struct NoirEffect: PhotoEffect {
    func apply(to image: CIImage, intensity: Double) -> CIImage {
        var result = image

        // Strong B&W base
        if let noir = CIFilter(name: "CIPhotoEffectNoir") {
            noir.setValue(result, forKey: kCIInputImageKey)
            result = noir.outputImage ?? result
        }

        // Punch contrast and deepen shadows
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(result, forKey: kCIInputImageKey)
            controls.setValue(1.35, forKey: kCIInputContrastKey)
            controls.setValue(-0.06, forKey: kCIInputBrightnessKey)
            controls.setValue(0, forKey: kCIInputSaturationKey)
            result = controls.outputImage ?? result
        }

        // Slight blue in shadows (noir film feel)
        if let matrix = CIFilter(name: "CIColorMatrix") {
            matrix.setValue(result, forKey: kCIInputImageKey)
            matrix.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
            matrix.setValue(CIVector(x: 0, y: 0.98, z: 0.02, w: 0), forKey: "inputGVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: 1.02, w: 0), forKey: "inputBVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: 0.01, w: 0), forKey: "inputBiasVector")
            result = matrix.outputImage ?? result
        }

        return EffectCompositor.mix(original: image, filtered: result, amount: intensity)
    }
}
