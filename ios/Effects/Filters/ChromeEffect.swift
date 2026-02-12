//
//  ChromeEffect.swift
//  Effects
//

import CoreImage

struct ChromeEffect: PhotoEffect {
    func apply(to image: CIImage, intensity: Double) -> CIImage {
        var result = image

        if let chrome = CIFilter(name: "CIPhotoEffectChrome") {
            chrome.setValue(result, forKey: kCIInputImageKey)
            result = chrome.outputImage ?? result
        }

        // Punchy saturation + clarity-like contrast
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(result, forKey: kCIInputImageKey)
            controls.setValue(1.25, forKey: kCIInputSaturationKey)
            controls.setValue(1.12, forKey: kCIInputContrastKey)
            controls.setValue(0.02, forKey: kCIInputBrightnessKey)
            result = controls.outputImage ?? result
        }

        // Slight highlight boost (vivid look)
        if let gamma = CIFilter(name: "CIGammaAdjust") {
            gamma.setValue(result, forKey: kCIInputImageKey)
            gamma.setValue(0.95, forKey: "inputPower")
            result = gamma.outputImage ?? result
        }

        return EffectCompositor.mix(original: image, filtered: result, amount: intensity)
    }
}
