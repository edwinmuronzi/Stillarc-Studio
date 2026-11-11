#if DEBUG
import CoreImage
import Foundation

enum BrushVerification {
    static func run() async throws -> [String:Any] {
        func require(_ v:Bool,_ message:String) throws { if !v { throw NSError(domain:"BrushVerification",code:1,userInfo:[NSLocalizedDescriptionKey:message]) } }
        let context = ImageEngine.context(),extent = CGRect(x:0,y:0,width:200,height:100)
        func pixel(_ image:CIImage,_ x:Int,_ y:Int) -> Float { var p = [Float](repeating:0,count:4);context.render(image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:x,y:y,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p[0] }
        var drawing = BrushDrawing()
        let stroke = drawing.begin(point:BrushPoint(x:0.25,y:0.2),radius:0.1,feather:0.5,erase:false)!
        let dot = BrushMaskRasterizer.image(drawing,extent:extent,preview:false)
        try require(pixel(dot,50,80)>0.95 && pixel(dot,50,20)<0.001,"Brush coordinate orientation incorrect")
        try require(pixel(dot,57,80)>0.1 && pixel(dot,57,80)<0.8,"Brush soft edge incorrect")
        drawing.append(BrushPoint(x:0.75,y:0.2),stroke:stroke)
        let line = BrushMaskRasterizer.image(drawing,extent:extent,preview:false)
        try require(pixel(line,100,80)>0.9,"Stroke interpolation left gaps")
        _ = drawing.begin(point:BrushPoint(x:0.5,y:0.2),radius:0.04,feather:0.2,erase:true)
        let erased = BrushMaskRasterizer.image(drawing,extent:extent,preview:false)
        try require(pixel(erased,100,80)<0.05 && pixel(erased,55,80)>0.9,"Eraser did not remove only its area")
        let raster = BrushMaskRasterizer.Raster(width:200,height:100)!
        var progressive = BrushDrawing();let id = progressive.begin(point:BrushPoint(x:0.1,y:0.5),radius:0.06,feather:0.6,erase:false)!
        _ = raster.render(progressive)
        for x in [0.2,0.35,0.55,0.8] { progressive.append(BrushPoint(x:x,y:0.5),stroke:id);_ = raster.render(progressive) }
        let incremental = CIImage(cgImage:raster.render(progressive)!,options:[.colorSpace:NSNull()])
        let full = BrushMaskRasterizer.image(progressive,extent:extent,preview:false)
        for x in stride(from:10,to:190,by:7) { try require(abs(pixel(incremental,x,50)-pixel(full,x,50))<0.005,"Incremental raster differs from export") }
        let priorRevision = progressive.revision
        progressive.append(BrushPoint(x:0.9,y:0.5),stroke:id)
        try require(priorRevision != progressive.revision,"Brush revision did not change")
        var layer = LocalMask(kind:.brush);layer.brush = drawing;layer.exposure = 1
        var recipe = Recipe();recipe.masks = [layer]
        let restored = try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(recipe))
        try require(restored == recipe,"Brush strokes did not persist")
        var legacy = try JSONSerialization.jsonObject(with:JSONEncoder().encode(LocalMask(kind:.radial))) as! [String:Any];legacy.removeValue(forKey:"brush")
        let old = try JSONDecoder().decode(LocalMask.self,from:JSONSerialization.data(withJSONObject:legacy));try require(old.brush == nil,"Old gradient masks did not migrate")
        try require(recipe.colorPreset.masks.isEmpty && AdjustmentClipboard(name:"Test",recipe:recipe,sections:Set(AdjustmentSection.allCases)).recipe.masks.isEmpty,"Brush leaked into reusable grades")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("StudioBrushQA-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let source = CIImage(color:CIColor(red:0.18,green:0.18,blue:0.18,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:extent)
        let file = root.appendingPathComponent("source.png")
        try context.writePNGRepresentation(of:source,to:file,format:.RGBA8,colorSpace:ImageEngine.output)
        let bytes = try Data(contentsOf:file)
        let output = try ImageEngine.export(source:file,recipe:recipe,format:.png)
        defer { try? FileManager.default.removeItem(at:output.url) }
        let reopened = try ImageEngine.open(output.url).image
        try require(pixel(reopened,55,80)>0.33 && pixel(reopened,100,80)<0.21 && pixel(reopened,50,20)<0.21,"Brush export or erased/outside area incorrect")
        try require(try Data(contentsOf:file) == bytes,"Brush export changed the original")
        let prepared = try BrushMaskRasterizer.prepareExport(layers:[layer],extent:extent)
        try require(prepared.images.values.first?.bitsPerComponent == 16,"Export mask is not 16-bit")
        let latest = BrushMaskRasterizer.image(drawing,extent:extent,preview:false)
        _ = BrushMaskRasterizer.image(drawing,extent:extent,preview:true)
        var ready = false
        for _ in 0..<100 {
            try await Task.sleep(for:.milliseconds(10))
            let preview = BrushMaskRasterizer.image(drawing,extent:extent,preview:true)
            if pixel(preview,55,80)>0.9 { ready = true;break }
        }
        try require(ready && pixel(latest,55,80)>0.9,"Background preview did not converge")
        let large = try BrushMaskRasterizer.prepareExport(layers:[layer],extent:CGRect(x:0,y:0,width:8000,height:6000))
        try require(large.images.values.first?.width == 8000 && large.images.values.first?.height == 6000 && large.images.values.first?.bitsPerComponent == 16,"Full-resolution brush mask was reduced")
        let before = drawing
        _ = drawing.begin(point:BrushPoint(x:0.9,y:0.9),radius:0.02,feather:0.5,erase:false)
        let reloaded = try JSONDecoder().decode(BrushDrawing.self,from:JSONEncoder().encode(before))
        try require(reloaded == before,"Saved brush changed after later edits")
        return ["passed":true,"coordinates":true,"softEdge":true,"strokeContinuity":true,"eraser":true,"incrementalMatchesExport":true,"uniqueRevision":true,"persistence":true,"legacyMasks":true,"gradeIsolation":true,"immutableSnapshot":true,"PNGExport":true,"originalPreserved":true,"sixteenBitExportMask":true,"backgroundPreviewConverges":true,"full48MPMaskDimensions":true]
    }
}
#endif
