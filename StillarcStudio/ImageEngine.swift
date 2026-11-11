import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import Metal
import UniformTypeIdentifiers

struct PreparedPhoto: @unchecked Sendable {
    let image: CIImage
    let width: Int
    let height: Int
    let isRAW: Bool
}
struct ExportResult: Sendable { let url: URL; let width: Int; let height: Int }
enum StudioError: LocalizedError {
    case unreadable, render, unsupportedPreset
    var errorDescription: String? {
        switch self {
        case .unreadable: "This file could not be opened. Try an original JPEG, HEIF, PNG, TIFF or supported RAW photograph."
        case .render: "The image could not be rendered. Your original and saved adjustments are safe."
        case .unsupportedPreset: "This preset uses an unsupported format."
        }
    }
}
// Separate queues/contexts for import/export and display: exports cannot block slider updates.
enum ImageEngine {
    static let working = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    static let output = CGColorSpace(name: CGColorSpace.sRGB)!
    static func context() -> CIContext {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device, options: [.workingColorSpace: working, .cacheIntermediates: false, .priorityRequestLow: true])
        }
        return CIContext(options: [.workingColorSpace: working, .cacheIntermediates: false, .priorityRequestLow: true])
    }
    static func open(_ url: URL, maxDimension: Double? = nil) throws -> PreparedPhoto {
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        let type = source.flatMap { CGImageSourceGetType($0) }.flatMap { UTType($0 as String) }
        let raw = type?.conforms(to: .rawImage) == true || ["dng","nef","arw","cr2","cr3","raf","orf","rw2"].contains(url.pathExtension.lowercased())
        var image: CIImage
        var nativeWidth = 0, nativeHeight = 0
        if raw {
            guard let filter = CIRAWFilter(imageURL: url), let fullGraph = filter.outputImage else { throw StudioError.unreadable }
            nativeWidth = Int(fullGraph.extent.width); nativeHeight = Int(fullGraph.extent.height)
            if let maxDimension {
                // Tell the RAW decoder the intended size, rather than demosaicing at full resolution.
                filter.scaleFactor = Float(min(1, maxDimension / max(fullGraph.extent.width, fullGraph.extent.height)))
            }
            guard let developed = filter.outputImage else { throw StudioError.unreadable }
            image = developed
            // Develop and cache once; sliders never repeatedly demosaic the original.
            if maxDimension != nil {
                guard let raster = context().createCGImage(image, from: image.extent, format: .RGBAh, colorSpace: working) else { throw StudioError.render }
                image = CIImage(cgImage: raster)
            }
        } else if let source, let maxDimension {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            nativeWidth = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
            nativeHeight = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
            let orientation = properties?[kCGImagePropertyOrientation] as? Int ?? 1
            if [5,6,7,8].contains(orientation) { swap(&nativeWidth, &nativeHeight) }
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension), kCGImageSourceShouldCacheImmediately: true]
            guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw StudioError.unreadable }
            image = CIImage(cgImage: cg)
        } else {
            guard let decoded = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else { throw StudioError.unreadable }
            image = decoded; nativeWidth = Int(image.extent.width); nativeHeight = Int(image.extent.height)
        }
        guard image.extent.width > 0, image.extent.height > 0, !image.extent.isInfinite else { throw StudioError.unreadable }
        image = image.transformed(by: .init(translationX: -image.extent.minX, y: -image.extent.minY))
        return PreparedPhoto(image: image, width: nativeWidth, height: nativeHeight, isRAW: raw)
    }
    static func apply(_ source: CIImage, recipe r: Recipe) -> CIImage {
        var image = source
        func filter(_ name: String, _ values: [String: Any]) { image = image.applyingFilter(name, parameters: values) }
        if r.exposure != 0 { filter("CIExposureAdjust", [kCIInputEVKey: r.exposure]) }
        if r.warmth != 0 || r.tint != 0 {
            filter("CITemperatureAndTint", ["inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: 6500 + r.warmth * 2400, y: r.tint * 100)])
        }
        if r.highlights != 0 || r.shadows != 0 {
            filter("CIHighlightShadowAdjust", ["inputHighlightAmount": 1 - r.highlights * 0.65, "inputShadowAmount": r.shadows * 0.7])
        }
        if r.contrast != 0 || r.saturation != 0 {
            filter("CIColorControls", [kCIInputContrastKey: 1 + r.contrast * 0.5, kCIInputSaturationKey: 1 + r.saturation])
        }
        if r.vibrance != 0 { filter("CIVibrance", ["inputAmount": r.vibrance]) }
        if r.curveShadows != 0 || r.curveMidtones != 0 || r.curveHighlights != 0 || r.fade != 0 {
            filter("CIToneCurve", ["inputPoint0": CIVector(x: 0, y: r.fade * 0.15), "inputPoint1": CIVector(x: 0.25, y: 0.25 + r.curveShadows * 0.15), "inputPoint2": CIVector(x: 0.5, y: 0.5 + r.curveMidtones * 0.2), "inputPoint3": CIVector(x: 0.75, y: 0.75 + r.curveHighlights * 0.15), "inputPoint4": CIVector(x: 1, y: 1)])
        }
        if r.look != .original && r.lookAmount > 0 {
            let base = image
            switch r.look {
            case .original: break
            case .daylight:
                filter("CIColorControls", [kCIInputSaturationKey: 0.92, kCIInputContrastKey: 1.06])
                filter("CITemperatureAndTint", ["inputNeutral": CIVector(x: 6500,y: 0), "inputTargetNeutral": CIVector(x: 7100,y: 4)])
            case .bluehour:
                filter("CIColorMatrix", ["inputRVector": CIVector(x: 0.94,y: 0,z: 0,w: 0), "inputGVector": CIVector(x: 0,y: 1,z: 0,w: 0), "inputBVector": CIVector(x: 0,y: 0,z: 1.07,w: 0), "inputBiasVector": CIVector(x: 0.004,y: 0.008,z: 0.02,w: 0)])
                filter("CIColorControls", [kCIInputSaturationKey: 0.86])
            case .silver: filter("CIColorControls", [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.15])
            case .ember:
                filter("CITemperatureAndTint", ["inputNeutral": CIVector(x: 6500,y: 0), "inputTargetNeutral": CIVector(x: 7800,y: 8)])
                filter("CIColorControls", [kCIInputSaturationKey: 0.8])
            case .soft:
                filter("CIColorControls", [kCIInputSaturationKey: 0.78, kCIInputContrastKey: 0.9, kCIInputBrightnessKey: 0.025])
            }
            image = image.applyingFilter("CIDissolveTransition", parameters: [kCIInputTargetImageKey: base, kCIInputTimeKey: 1 - r.lookAmount])
        }
        if r.noise > 0 { filter("CINoiseReduction", ["inputNoiseLevel": r.noise * 0.05, "inputSharpness": 0.2]) }
        if r.sharpen > 0 { filter("CISharpenLuminance", [kCIInputSharpnessKey: r.sharpen * 0.8]) }
        // Radius is proportional to image size so preview and full export share a visual scale.
        let unit = max(image.extent.width, image.extent.height) / 1600
        if r.bloom > 0 { image = image.clampedToExtent().applyingFilter("CIBloom", parameters: [kCIInputRadiusKey: 9 * unit, kCIInputIntensityKey: r.bloom * 0.6]).cropped(to: image.extent) }
        if r.grain > 0, let random = CIFilter(name: "CIRandomGenerator")?.outputImage {
            let texture = random.transformed(by: .init(scaleX: max(0.5,unit), y: max(0.5,unit))).cropped(to: image.extent)
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                .applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0,y: 0,z: 0,w: r.grain * 0.2)])
            image = texture.applyingFilter("CISoftLightBlendMode", parameters: [kCIInputBackgroundImageKey: image])
        }
        if r.vignette > 0 { filter("CIVignette", [kCIInputIntensityKey: r.vignette * 1.6, kCIInputRadiusKey: max(image.extent.width,image.extent.height) * 0.6]) }
        if r.rotation % 4 != 0 { image = image.oriented(forExifOrientation: [1,6,3,8][((r.rotation % 4) + 4) % 4]) }
        if let ratio = r.crop.ratio {
            let e = image.extent
            let w = floor(min(e.width, e.height * ratio)), h = floor(min(e.height, e.width / ratio))
            image = image.cropped(to: CGRect(x: floor(e.midX - w/2), y: floor(e.midY - h/2), width: w, height: h))
        }
        return image.transformed(by: .init(translationX: -image.extent.minX, y: -image.extent.minY))
    }
    static func export(source: URL, recipe: Recipe, format: ExportFormat) throws -> ExportResult {
        try autoreleasepool {
            let original = try open(source)
            let image = apply(original.image, recipe: recipe)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Stillarc-\(UUID().uuidString.prefix(8)).\(format.ext)")
            let context = context()
            if format == .jpeg {
                try context.writeJPEGRepresentation(of: image, to: url, colorSpace: output, options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.96])
            } else {
                try context.writePNGRepresentation(of: image, to: url, format: .RGBA8, colorSpace: output)
            }
            return ExportResult(url: url, width: Int(image.extent.width), height: Int(image.extent.height))
        }
    }
}
enum ExportFormat: String, CaseIterable, Identifiable { case jpeg = "JPEG", png = "PNG"; var id: String { rawValue }; var ext: String { self == .jpeg ? "jpg" : "png" } }
