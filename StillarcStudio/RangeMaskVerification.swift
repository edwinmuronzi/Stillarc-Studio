#if DEBUG
import CoreImage
import Foundation

enum RangeMaskVerification {
    static func run() throws -> [String:Any] {
        func check(_ value:Bool,_ text:String) throws { if !value { throw NSError(domain:"RangeMaskVerification",code:1,userInfo:[NSLocalizedDescriptionKey:text]) } }
        try RangeMaskKernel.prepare()
        let extent = CGRect(x:0,y:0,width:64,height:64),context = ImageEngine.context()
        func image(_ v:Double,_ g:Double? = nil,_ b:Double? = nil) -> CIImage { CIImage(color:CIColor(red:v,green:g ?? v,blue:b ?? v,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:extent) }
        func sample(_ image:CIImage) -> [Float] { var p = [Float](repeating:0,count:4);context.render(image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:32,y:32,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p }
        func weight(_ m:LocalMask,_ source:CIImage) -> Float { sample(MaskEngine.weight(m,extent:extent,reference:source))[0] }
        let red = image(0.3,0,0),gray = image(0.18)
        var color = LocalMask(kind:.color);color.exposure = 1
        try check(weight(color,red)>0.99 && weight(color,image(0,0.3,0))<0.001 && weight(color,gray)<0.001,"Hue/neutral isolation")
        color.selection?.hue = 359;let left = weight(color,red);color.selection?.hue = 1
        try check(left>0.99 && weight(color,red)>0.99,"Hue wrap")
        color.selection?.hue = 0;color.selection?.softness = 0.5
        let edge = weight(color,image(0.3,0.12,0));try check(edge>0 && edge<1,"Color feather")
        var inverse = color;inverse.inverted = true
        try check(abs(weight(color,red)+weight(inverse,red)-1)<0.002,"Inverse")
        color.amount = 0.5;try check(abs(weight(color,red)-0.5)<0.002,"Strength")
        var lum = LocalMask(kind:.luminance);lum.selection = MaskSelection(lower:0.4,upper:0.45,softness:0.05);lum.exposure = 1
        try check(weight(lum,gray)>0.99 && weight(lum,image(0.01))<0.001 && weight(lum,image(1))<0.001,"Brightness isolation")
        try check(abs(weight(lum,image(0.140625))-0.5)<0.02,"Luminance feather")
        try check(abs(sample(MaskEngine.apply(gray,layers:[lum,lum]))[0]-0.72)<0.005,"Pre-local reference")
        let guide = sample(MaskEngine.overlay(MaskEngine.apply(gray,layers:[lum]),layer:lum,reference:gray))
        try check(guide[0]>guide[1]+0.1,"Guide reference")
        var all = lum;all.selection = MaskSelection(lower:0,upper:1)
        try check(weight(all,image(0))>0.99 && weight(all,image(4))>0.99,"Black/HDR endpoints")
        try HDRPipeline.prepare()
        var hdrRecipe = Recipe();var hdrMask = LocalMask(kind:.luminance);hdrMask.selection = MaskSelection(lower:0.9,upper:1);hdrMask.exposure = -1;hdrRecipe.masks = [hdrMask]
        let bright = image(4),reference = HDRPipeline.maskReference(bright,recipe:hdrRecipe,hdr:true)
        try check(abs(sample(reference)[0]-1)<0.002 && abs(sample(HDRPipeline.grade(bright,recipe:hdrRecipe,hdr:true))[0]-2)<0.01,"HDR normalization/selection")
        var recipe = Recipe();recipe.masks = [color,lum]
        try check(try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(recipe)) == recipe,"Persistence")
        try check(recipe.colorPreset.masks.isEmpty && AdjustmentClipboard(name:"QA",recipe:recipe,sections:Set(AdjustmentSection.allCases)).recipe.masks.isEmpty,"Preset/copy isolation")
        var bad = MaskSelection();bad.hue = .nan;bad.lower = 0.9;bad.upper = 0.2;bad.softness = .infinity
        let safe = bad.validated();try check(safe.hue.isFinite && safe.lower<=safe.upper && safe.softness.isFinite,"Validation")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("RangeQA-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let file = root.appendingPathComponent("original.png")
        try context.writePNGRepresentation(of:gray,to:file,format:.RGBA8,colorSpace:ImageEngine.output)
        let bytes = try Data(contentsOf:file)
        var exportRecipe = Recipe();exportRecipe.masks = [lum]
        let result = try ImageEngine.export(source:file,recipe:exportRecipe,format:.png)
        defer { try? FileManager.default.removeItem(at:result.url) }
        let p = sample(try ImageEngine.open(result.url).image)
        try check(abs(p[0]-0.36)<0.01 && abs(p[0]-p[1])<0.002,"Export/guide isolation")
        try check(try Data(contentsOf:file) == bytes,"Original preservation")
        return ["passed":true,"hueIsolationWrap":true,"softTransitions":true,"inversionStrength":true,"brightnessIsolation":true,"preLocalReference":true,"guideReference":true,"HDRBlackEndpoints":true,"HDRSelectionReference":true,"persistence":true,"presetCopyIsolation":true,"validation":true,"photoExportNoGuide":true,"originalPreserved":true]
    }
}
#endif
