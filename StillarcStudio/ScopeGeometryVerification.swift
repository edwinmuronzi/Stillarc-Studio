#if DEBUG
import CoreImage
import Foundation

enum ScopeGeometryVerification {
    static func run() throws -> [String:Any] {
        func require(_ v:Bool,_ message:String) throws { if !v { throw NSError(domain:"ScopeGeometry",code:1,userInfo:[NSLocalizedDescriptionKey:message]) } }
        let scope = ScopeAnalysis.analyze([1,0,0,1,0,1,0,1,0,0,1,1],width:3,height:1,hdr:false)
        try require(scope.histogram.allSatisfy { $0[255] == 1 && $0[0] == 2 && $0.reduce(0,+) == 3 },"RGB scope bins incorrect")
        try require(scope.waveform != nil && scope.vectorscope != nil,"Scope raster unavailable")
        let hdr = ScopeAnalysis.analyze([4,4,4,1,8,8,8,1],width:2,height:1,hdr:true)
        try require(hdr.histogram[0][127] == 1 && hdr.histogram[0][255] == 1 && hdr.ceiling == 0.5,"HDR scope scale incorrect")
        let context = ImageEngine.context()
        let source = CIImage(color:CIColor(red:0.3,green:0.5,blue:0.7,alpha:1)).cropped(to:CGRect(x:0,y:0,width:320,height:180))
        let red = CIImage(color:CIColor(red:1,green:0,blue:0)).cropped(to:CGRect(x:0,y:0,width:160,height:90))
        let green = CIImage(color:CIColor(red:0,green:1,blue:0)).cropped(to:CGRect(x:0,y:90,width:160,height:90))
        let blue = CIImage(color:CIColor(red:0,green:0,blue:1)).cropped(to:source.extent)
        let quadrants = red.composited(over:green.composited(over:blue))
        func sample(_ image:CIImage) -> [Float] { var p = [Float](repeating:0,count:4);context.render(image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:40,y:40,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p }
        var flip = Recipe();flip.geometry.flipHorizontal = true
        try require(sample(PhotoFraming.apply(quadrants,recipe:flip))[2]>0.99,"Horizontal flip did not mirror pixels")
        flip.geometry.flipHorizontal = false;flip.geometry.flipVertical = true
        try require(sample(PhotoFraming.apply(quadrants,recipe:flip))[1]>0.99,"Vertical flip did not mirror pixels")
        var r = Recipe();r.crop = .free;r.geometry.width = 0.75;r.geometry.height = 0.5;r.geometry.flipHorizontal = true;r.geometry.vertical = 0.2
        try require(PhotoFraming.apply(source,recipe:r).extent.size == CGSize(width:240,height:90),"Free crop size changed")
        let reopened = try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(r))
        try require(reopened == r && r.colorPreset.geometry.isNeutral,"Geometry save or preset isolation failed")
        var reset = r;reset.reset(.crop);try require(reset.geometry.isNeutral && !reset.hasAdjustments(in:.crop),"Geometry reset/dot failed")
        var count = 0
        for rotation in 0..<4 { for horizontal in [-0.3,0,0.3] { for vertical in [-0.3,0,0.3] {
            r.rotation = rotation;r.geometry.horizontal = horizontal;r.geometry.vertical = vertical;r.straighten = 5
            let image = PhotoFraming.apply(source,recipe:r)
            let small = image.transformed(by:.init(scaleX:32/image.extent.width,y:32/image.extent.height))
            var pixels = [Float](repeating:0,count:32*32*4)
            context.render(small,toBitmap:&pixels,rowBytes:32*16,bounds:CGRect(x:0,y:0,width:32,height:32),format:.RGBAf,colorSpace:ImageEngine.working)
            for y in 2..<30 { for x in 2..<30 { try require(pixels[(y*32+x)*4+3]>0.99,"Perspective left empty corners") } }
            count += 1
        } } }
        let old = try JSONDecoder().decode(Recipe.self,from:Data("{}".utf8))
        try require(old.geometry.isNeutral,"Old geometry defaults changed")
        return ["passed":true,"geometryCombinations":count,"RGBBins":true,"HDRScale":true,"rasterScopes":true,"legacyDefaults":true,"presetIsolation":true,"geometryPersistence":true]
    }
}
#endif
