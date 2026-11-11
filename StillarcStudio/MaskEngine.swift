import CoreImage

enum MaskEngine {
    private final class Warmup: @unchecked Sendable {
        init() {
            let image = CIImage(color:CIColor(red:0.18,green:0.2,blue:0.3)).cropped(to:CGRect(x:0,y:0,width:32,height:32))
            var a = LocalMask(kind:.linear);a.exposure = 0.2;a.warmth = 0.1
            var b = LocalMask(kind:.radial);b.saturation = 0.1;b.contrast = 0.1
            let graph = MaskEngine.overlay(MaskEngine.apply(image,layers:[a,b]),layer:b)
            _ = ImageEngine.context().createCGImage(graph,from:graph.extent,format:.RGBAh,colorSpace:ImageEngine.working)
        }
    }
    private static let warmup = Warmup()
    static func prepare() { _ = warmup }
    static func weight(_ layer:LocalMask,extent:CGRect,preview:Bool = false) -> CIImage {
        let m = layer.validated(),angle = m.angle*Double.pi/180
        let center = CGPoint(x:extent.minX+extent.width*m.centerX,y:extent.minY+extent.height*(1-m.centerY))
        var mask:CIImage
        if m.kind == .brush { mask = BrushMaskRasterizer.image(m.brush,extent:extent,preview:preview) }
        else if m.kind == .linear {
            let dx = cos(angle)*extent.width*m.width*m.feather,dy = sin(angle)*extent.height*m.width*m.feather
            mask = CIFilter(name:"CILinearGradient",parameters:["inputPoint0":CIVector(x:center.x-dx/2,y:center.y-dy/2),"inputPoint1":CIVector(x:center.x+dx/2,y:center.y+dy/2),"inputColor0":CIColor.black,"inputColor1":CIColor.white])!.outputImage!
        } else {
            let radius = extent.width*m.width
            mask = CIFilter(name:"CIRadialGradient",parameters:["inputCenter":CIVector(x:0,y:0),"inputRadius0":radius*(1-m.feather),"inputRadius1":radius,"inputColor0":CIColor.white,"inputColor1":CIColor.black])!.outputImage!
                .transformed(by:.init(scaleX:1,y:extent.height*m.height/radius))
                .transformed(by:.init(rotationAngle:angle))
                .transformed(by:.init(translationX:center.x,y:center.y))
        }
        mask = mask.cropped(to:extent)
        if m.inverted { mask = mask.applyingFilter("CIColorInvert") }
        if m.amount<1 { mask = mask.applyingFilter("CIColorMatrix",parameters:["inputRVector":CIVector(x:m.amount,y:0,z:0,w:0),"inputGVector":CIVector(x:0,y:m.amount,z:0,w:0),"inputBVector":CIVector(x:0,y:0,z:m.amount,w:0)]) }
        return mask
    }
    static func apply(_ source:CIImage,layers:[LocalMask],preview:Bool = false) -> CIImage {
        var image = source
        for raw in layers.prefix(4) where raw.hasEffect {
            let m = raw.validated()
            var adjusted = image
            if m.exposure != 0 { adjusted = adjusted.applyingFilter("CIExposureAdjust",parameters:[kCIInputEVKey:m.exposure]) }
            if m.warmth != 0 { adjusted = adjusted.applyingFilter("CITemperatureAndTint",parameters:["inputNeutral":CIVector(x:6500,y:0),"inputTargetNeutral":CIVector(x:6500+m.warmth*2400,y:0)]) }
            if m.saturation != 0 || m.contrast != 0 { adjusted = adjusted.applyingFilter("CIColorControls",parameters:[kCIInputSaturationKey:1+m.saturation,kCIInputContrastKey:1+m.contrast*0.5]) }
            image = adjusted.applyingFilter("CIBlendWithMask",parameters:[kCIInputBackgroundImageKey:image,kCIInputMaskImageKey:weight(m,extent:image.extent,preview:preview)])
        }
        return image
    }
    static func overlay(_ image:CIImage,layer:LocalMask?) -> CIImage {
        guard let layer else { return image }
        let red = CIImage(color:CIColor(red:1,green:0.1,blue:0.05,alpha:0.3)).cropped(to:image.extent).composited(over:image)
        return red.applyingFilter("CIBlendWithMask",parameters:[kCIInputBackgroundImageKey:image,kCIInputMaskImageKey:weight(layer,extent:image.extent,preview:true)])
    }
}
