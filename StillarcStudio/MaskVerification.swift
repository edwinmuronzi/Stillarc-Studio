#if DEBUG
import CoreImage
import Foundation

enum MaskVerification {
    static func run() throws -> [String:Any] {
        func require(_ v:Bool,_ message:String) throws { if !v { throw NSError(domain:"MaskVerification",code:1,userInfo:[NSLocalizedDescriptionKey:message]) } }
        let context = ImageEngine.context(),extent = CGRect(x:0,y:0,width:100,height:100)
        func sample(_ image:CIImage,x:Int,y:Int) -> [Float] { var p = [Float](repeating:0,count:4);context.render(image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:x,y:y,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p }
        var radial = LocalMask(kind:.radial);radial.width = 0.2;radial.height = 0.2;radial.feather = 0.6
        let weight = MaskEngine.weight(radial,extent:extent)
        try require(sample(weight,x:50,y:50)[0]>0.99 && sample(weight,x:90,y:50)[0]<0.001,"Radial center/outside weights incorrect")
        let edge = sample(weight,x:65,y:50)[0]
        try require(edge>0.25 && edge<0.55,"Radial feather was not continuous")
        var inverse = radial;inverse.inverted = true
        try require(abs(sample(weight,x:65,y:50)[0]+sample(MaskEngine.weight(inverse,extent:extent),x:65,y:50)[0]-1)<0.002,"Mask inversion is not complementary")
        var linear = LocalMask(kind:.linear);linear.angle = 90
        let ramp = MaskEngine.weight(linear,extent:extent)
        try require(sample(ramp,x:50,y:90)[0]>0.99 && sample(ramp,x:50,y:10)[0]<0.001,"Linear mask direction incorrect")
        let source = CIImage(color:CIColor(red:0.18,green:0.18,blue:0.18,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:extent)
        try require(MaskEngine.apply(source,layers:[radial]) === source,"Neutral mask did not bypass grading")
        radial.exposure = 1
        let adjusted = MaskEngine.apply(source,layers:[radial])
        try require(abs(sample(adjusted,x:50,y:50)[0]-0.36)<0.003 && abs(sample(adjusted,x:90,y:50)[0]-0.18)<0.003,"Masked exposure affected the wrong pixels")
        radial.enabled = false;try require(MaskEngine.apply(source,layers:[radial]) === source,"Disabled mask still rendered")
        radial.enabled = true;radial.amount = 0.5
        try require(abs(sample(MaskEngine.apply(source,layers:[radial]),x:50,y:50)[0]-0.27)<0.004,"Mask strength did not blend linearly")
        var recipe = Recipe();recipe.masks = [radial,linear];recipe.crop = .square
        try require(try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(recipe)) == recipe,"Mask recipe did not round-trip")
        try require(recipe.colorPreset.masks.isEmpty,"Spatial masks leaked into a reusable preset")
        let copied = AdjustmentClipboard(name:"Test",recipe:recipe,sections:Set(AdjustmentSection.allCases));try require(copied.recipe.masks.isEmpty,"Copied grade leaked spatial masks")
        var target = Recipe();target.masks = [inverse]
        try require(target.pasting(recipe,sections:Set(AdjustmentSection.allCases)).masks == target.masks,"Paste replaced destination masks")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("StudioMaskQA-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let file = root.appendingPathComponent("source.png")
        try context.writePNGRepresentation(of:source,to:file,format:.RGBA8,colorSpace:ImageEngine.output)
        let bytes = try Data(contentsOf:file)
        var photo = Recipe();photo.masks = [radial]
        let exported = try ImageEngine.export(source:file,recipe:photo,format:.png)
        defer { try? FileManager.default.removeItem(at:exported.url) }
        let output = try ImageEngine.open(exported.url).image,p = sample(output,x:50,y:50)
        try require(p[0]>0.25 && abs(p[0]-p[1])<0.003 && abs(p[1]-p[2])<0.003,"Export lost the local adjustment or included the red guide")
        try require(try Data(contentsOf:file) == bytes,"Masked export changed the original")
        let old = try JSONDecoder().decode(Recipe.self,from:Data("{}".utf8));try require(old.masks.isEmpty,"Legacy masks were not neutral")
        var tooMany = Recipe();tooMany.masks = (0..<8).map { _ in LocalMask(kind:.radial) }
        let limited = try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(tooMany));try require(limited.masks.count == 4,"Mask count was not bounded")
        var invalid = radial;invalid.width = 0;invalid.height = .infinity;invalid.centerX = .nan
        let safe = invalid.validated();try require(safe.width>0 && safe.height.isFinite && safe.centerX.isFinite,"Mask bounds did not sanitize")
        return ["passed":true,"radialFeather":true,"linearDirection":true,"inversion":true,"localExposure":true,"strength":true,"neutralDisabledBypass":true,"persistence":true,"presetCopyIsolation":true,"destinationMasksPreserved":true,"legacyDefaults":true,"boundedLayers":true,"photoExportNoGuide":true,"originalPreserved":true]
    }
}
#endif
