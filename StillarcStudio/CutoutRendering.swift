import CoreImage

extension Recipe {
    var hasCutout:Bool {masks.contains { $0.enabled && $0.cutout == true && $0.amount>0 }}
    mutating func setCutout(_ id:UUID,enabled:Bool) {
        for i in masks.indices {
            if masks[i].id==id {masks[i].cutout=enabled;if enabled {masks[i].enabled=true;if masks[i].amount<=0 {masks[i].amount=1}}}
            else if enabled {masks[i].cutout=nil}
        }
    }
}
enum CutoutRendering {
    static func apply(_ source:CIImage,layers:[LocalMask],preview:Bool,framing:String?,reference:CIImage? = nil) -> CIImage {
        guard let raw=layers.prefix(4).first(where:{$0.enabled && $0.cutout == true && $0.amount>0}) else {return source}
        let layer=raw.validated(),extent=source.extent
        // Show the working image, rather than an empty frame, while a crop/selection is being repaired.
        if layer.kind.isAutomatic {
            guard let mask=layer.automatic,framing==nil || mask.framing==framing,
                  AutomaticMaskBitmap.image(mask,extent:extent,preview:preview) != nil else {return source}
        }
        var full=layer;full.amount=1
        var weight=MaskEngine.combinedWeight(full,layers:layers,extent:extent,preview:preview,reference:reference ?? source,framing:framing)
        if layer.amount<1 {
            let a=layer.amount
            weight=weight.applyingFilter("CIColorMatrix",parameters:["inputRVector":CIVector(x:a,y:0,z:0,w:0),"inputGVector":CIVector(x:0,y:a,z:0,w:0),"inputBVector":CIVector(x:0,y:0,z:a,w:0),"inputBiasVector":CIVector(x:1-a,y:1-a,z:1-a,w:0)])
        }
        let clear=CIImage(color:.clear).cropped(to:extent)
        return source.applyingFilter("CIBlendWithMask",parameters:[kCIInputBackgroundImageKey:clear,kCIInputMaskImageKey:weight]).cropped(to:extent)
    }
    static func checkerboard(_ extent:CGRect) -> CIImage {
        CIFilter(name:"CICheckerboardGenerator",parameters:["inputCenter":CIVector(x:0,y:0),"inputColor0":CIColor(red:0.12,green:0.14,blue:0.17),"inputColor1":CIColor(red:0.21,green:0.23,blue:0.26),"inputWidth":12,"inputSharpness":1])!.outputImage!.cropped(to:extent)
    }
}
