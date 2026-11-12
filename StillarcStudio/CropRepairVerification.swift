#if DEBUG
import CoreImage
import Foundation

enum CropRepairVerification {
    static func run() async throws -> [String:Any] {
        func check(_ v:Bool,_ text:String) throws { if !v { throw NSError(domain:"CropRepairQA",code:1,userInfo:[NSLocalizedDescriptionKey:text]) } }
        let context = ImageEngine.context(),extent = CGRect(x:0,y:0,width:100,height:120)
        let shape = CIImage(color:.white).cropped(to:CGRect(x:50,y:60,width:50,height:60)).composited(over:CIImage(color:.black).cropped(to:extent))
        var base = Recipe(),layer = LocalMask(kind:.sky)
        layer.automatic = try AutomaticMaskBitmap.make(shape,recipe:base,videoStart:nil);layer.exposure = 1;base.masks = [layer]
        var crop = base;crop.crop = .square;crop.geometry.cropScale = 0.6
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CropRepair-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer { try? FileManager.default.removeItem(at:root) }
        let source = root.appendingPathComponent("source.png"),image = CIImage(color:CIColor(red:0.18,green:0.18,blue:0.18,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:extent)
        try context.writePNGRepresentation(of:image,to:source,format:.RGBA8,colorSpace:ImageEngine.output)
        let bytes = try Data(contentsOf:source),analyses = AutomaticSelectionEngine.analysisCount
        let repaired = try await MaskFramingRepair.repair(recipe:crop,url:source,video:nil,prepared:nil)
        try check(repaired.masks[0].automatic?.matches(repaired) == true,"Crop selection did not repair")
        _ = try AutomaticMaskBitmap.prepare(repaired)
        let exported = try ImageEngine.export(source:source,recipe:repaired,format:.png)
        defer { try? FileManager.default.removeItem(at:exported.url) }
        func sample(_ image:CIImage,_ x:Double,_ y:Double) -> Float { var p = [Float](repeating:0,count:4);context.render(image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:x,y:y,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p[0] }
        let output = try ImageEngine.open(exported.url).image
        try check(exported.width == 60 && exported.height == 60,"Cropped export dimensions")
        try check(abs(sample(output,45,45)-0.36)<0.012 && abs(sample(output,15,15)-0.18)<0.012,"Selection shifted or disappeared in export")
        var expanded = repaired;expanded.crop = .original;expanded.geometry.cropScale = 1
        let restored = try await MaskFramingRepair.repair(recipe:expanded,url:source,video:nil,prepared:nil)
        let matte = AutomaticMaskBitmap.image(restored.masks[0].automatic,extent:extent,preview:false)!
        try check(sample(matte,90,100)>0.99 && sample(matte,20,20)<0.001,"Expanded crop lost original matte")
        var tracked = base;tracked.masks[0].motion = MaskMotion(framing:MaskMotion.signature(base),start:0,end:2,points:[.init(time:0,x:0,y:0),.init(time:2,x:0.8,y:0)])
        tracked.crop = .square;tracked.geometry.cropScale = 0.6
        var unused = base;unused.rotation = 1;unused.masks[0].enabled = false
        let ignored = try await MaskFramingRepair.repair(recipe:unused,url:source,video:nil,prepared:nil)
        try check(try AutomaticMaskBitmap.prepare(ignored).isEmpty,"Inactive mask blocked export")
        let moved = try await MaskFramingRepair.repair(recipe:tracked,url:source,video:nil,prepared:nil)
        try MaskMotion.validateExport(moved,duration:2)
        try check(abs(moved.masks[0].motion!.points[1].x-0.8*100/60)<0.0001,"Tracked subject motion not scaled with crop")
        try check(try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(repaired)) == repaired,"Anchored selection save/reopen")
        try check(AutomaticSelectionEngine.analysisCount == analyses && (try Data(contentsOf:source)) == bytes,"Crop ran inference or modified source")
        return ["passed":true,"immediateCropExport":true,"selectedPixelsPreserved":true,"expandedCropRestoresAnchor":true,"trackingReframed":true,"legacyMaskSupported":true,"inactiveMasksNeverBlockExport":true,"noInferenceForCrop":true,"persistence":true]
    }
}
#endif
