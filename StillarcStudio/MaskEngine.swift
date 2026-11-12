import CoreImage

enum MaskEngine {
    private final class Warmup: @unchecked Sendable {
        init() {
            let image = CIImage(color:CIColor(red:0.18,green:0.2,blue:0.3)).cropped(to:CGRect(x:0,y:0,width:32,height:32))
            var a = LocalMask(kind:.linear);a.exposure = 0.2;a.warmth = 0.1
            var b = LocalMask(kind:.radial);b.saturation = 0.1;b.contrast = 0.1
            b.combination = .intersect
            var c = LocalMask(kind:.color);c.exposure = 0.1;c.combination = .add
            var d = LocalMask(kind:.luminance);d.exposure = 0.1;d.combination = .subtract
            let graph = MaskEngine.overlay(MaskEngine.apply(image,layers:[a,b,c,d]),layer:c,reference:image)
            _ = ImageEngine.context().createCGImage(graph,from:graph.extent,format:.RGBAh,colorSpace:ImageEngine.working)
        }
    }
    private static let warmup = Warmup()
    static func prepare() throws { try RangeMaskKernel.prepare();_ = warmup }
    static func weight(_ layer:LocalMask,extent:CGRect,preview:Bool = false,reference:CIImage? = nil,framing:String? = nil) -> CIImage {
        let m = layer.validated(),angle = m.angle*Double.pi/180
        let center = CGPoint(x:extent.minX+extent.width*m.centerX,y:extent.minY+extent.height*(1-m.centerY))
        var mask:CIImage
        if m.kind.isAutomatic {
            if let framing,let stored = m.automatic,stored.framing != framing { return CIImage(color:.black).cropped(to:extent) }
            guard let stored = m.automatic,stored.bounded,let decoded = AutomaticMaskBitmap.image(stored,extent:extent,preview:preview) else { return CIImage(color:.black).cropped(to:extent) };mask = decoded
            let r = (m.refinement ?? AutomaticRefinement()).validated(),short = min(extent.width,extent.height)
            if r.expand != 0 { mask = mask.applyingFilter(r.expand>0 ? "CIMorphologyMaximum" : "CIMorphologyMinimum",parameters:[kCIInputRadiusKey:abs(r.expand)*short]) }
            if r.softness>0 { mask = mask.clampedToExtent().applyingFilter("CIGaussianBlur",parameters:[kCIInputRadiusKey:r.softness*short]).cropped(to:extent) }
            if r.threshold != 0.5 || r.transition != 1 {
                let gain = 1/r.transition,bias = 0.5-r.threshold*gain
                mask = mask.applyingFilter("CIColorMatrix",parameters:["inputRVector":CIVector(x:gain,y:0,z:0,w:0),"inputGVector":CIVector(x:0,y:gain,z:0,w:0),"inputBVector":CIVector(x:0,y:0,z:gain,w:0),"inputBiasVector":CIVector(x:bias,y:bias,z:bias,w:0)]).applyingFilter("CIColorClamp")
            }
        }
        else if m.isRange { mask = reference.map { RangeMaskKernel.image($0,layer:m) } ?? CIImage(color:.black).cropped(to:extent) }
        else if m.kind == .brush { mask = BrushMaskRasterizer.image(m.brush,extent:extent,preview:preview) }
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
        if !m.isRange,let motion = m.motion,let frame = MaskMotion.frame,motion.framing == frame.framing {
            let offset = motion.offset(at:frame.time)
            mask = mask.cropped(to:extent).transformed(by:.init(translationX:offset.x*extent.width,y:-offset.y*extent.height))
                .composited(over:CIImage(color:.black).cropped(to:extent))
        }
        mask = mask.cropped(to:extent)
        if m.inverted { mask = mask.applyingFilter("CIColorInvert") }
        if m.amount<1 { mask = mask.applyingFilter("CIColorMatrix",parameters:["inputRVector":CIVector(x:m.amount,y:0,z:0,w:0),"inputGVector":CIVector(x:0,y:m.amount,z:0,w:0),"inputBVector":CIVector(x:0,y:0,z:m.amount,w:0)]) }
        return mask
    }
    static func requiredIndices(_ layers:[LocalMask]) -> Set<Int> {
        var needed = Set<Int>()
        for index in layers.prefix(4).indices where layers[index].hasEffect {
            var i = index;needed.insert(i)
            while i>0 && (layers[i].combination ?? .independent) != .independent { i -= 1;needed.insert(i) }
        }
        return needed
    }
    /// Previous coverage excludes adjustment strength/enabled state; this is selection composition.
    static func combinedWeight(_ layer:LocalMask,layers:[LocalMask],extent:CGRect,preview:Bool = false,reference:CIImage? = nil,framing:String? = nil) -> CIImage {
        guard let index = layers.prefix(4).firstIndex(where:{ $0.id == layer.id }) else { return weight(layer,extent:extent,preview:preview,reference:reference,framing:framing) }
        func coverage(_ index:Int) -> CIImage {
            var current = layers[index];current.amount = 1
            let own = weight(current,extent:extent,preview:preview,reference:reference,framing:framing)
            guard index>0,let mode = current.combination,mode != .independent else { return own }
            let previous = coverage(index-1)
            switch mode {
            case .independent:return own
            case .intersect:return own.applyingFilter("CIMultiplyCompositing",parameters:[kCIInputBackgroundImageKey:previous]).cropped(to:extent)
            case .add:return own.applyingFilter("CIMaximumCompositing",parameters:[kCIInputBackgroundImageKey:previous]).cropped(to:extent)
            case .subtract:return own.applyingFilter("CIMultiplyCompositing",parameters:[kCIInputBackgroundImageKey:previous.applyingFilter("CIColorInvert")]).cropped(to:extent)
            }
        }
        let selected = coverage(index),amount = layer.validated().amount
        return amount == 1 ? selected : selected.applyingFilter("CIColorMatrix",parameters:["inputRVector":CIVector(x:amount,y:0,z:0,w:0),"inputGVector":CIVector(x:0,y:amount,z:0,w:0),"inputBVector":CIVector(x:0,y:0,z:amount,w:0)])
    }
    static func apply(_ source:CIImage,layers:[LocalMask],preview:Bool = false,framing:String? = nil) -> CIImage {
        var image = source
        for raw in layers.prefix(4) where raw.hasEffect {
            let m = raw.validated()
            var adjusted = image
            if m.exposure != 0 { adjusted = adjusted.applyingFilter("CIExposureAdjust",parameters:[kCIInputEVKey:m.exposure]) }
            if m.warmth != 0 { adjusted = adjusted.applyingFilter("CITemperatureAndTint",parameters:["inputNeutral":CIVector(x:6500,y:0),"inputTargetNeutral":CIVector(x:6500+m.warmth*2400,y:0)]) }
            if m.saturation != 0 || m.contrast != 0 { adjusted = adjusted.applyingFilter("CIColorControls",parameters:[kCIInputSaturationKey:1+m.saturation,kCIInputContrastKey:1+m.contrast*0.5]) }
            image = adjusted.applyingFilter("CIBlendWithMask",parameters:[kCIInputBackgroundImageKey:image,kCIInputMaskImageKey:combinedWeight(m,layers:layers,extent:image.extent,preview:preview,reference:source,framing:framing)])
        }
        return image
    }
    static func overlay(_ image:CIImage,layer:LocalMask?,reference:CIImage? = nil,layers:[LocalMask] = [],framing:String? = nil) -> CIImage {
        guard let layer else { return image }
        let red = CIImage(color:CIColor(red:1,green:0.1,blue:0.05,alpha:0.3)).cropped(to:image.extent).composited(over:image)
        return red.applyingFilter("CIBlendWithMask",parameters:[kCIInputBackgroundImageKey:image,kCIInputMaskImageKey:combinedWeight(layer,layers:layers,extent:image.extent,preview:true,reference:reference ?? image,framing:framing)])
    }
}
