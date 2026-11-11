#if DEBUG
import CoreImage
import Foundation

enum MaskCombinationVerification {
    static func run() throws -> [String:Any] {
        func check(_ value:Bool,_ text:String) throws { if !value { throw NSError(domain:"MaskCombinationVerification",code:1,userInfo:[NSLocalizedDescriptionKey:text]) } }
        let extent = CGRect(x:0,y:0,width:100,height:100),context = ImageEngine.context()
        func sample(_ image:CIImage,_ x:Int,_ y:Int) -> Float { var p = [Float](repeating:0,count:4);context.render(image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:x,y:y,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p[0] }
        var a = LocalMask(kind:.linear);a.angle = 0;a.width = 0.4;a.feather = 1;a.enabled = false;a.amount = 0
        var b = LocalMask(kind:.linear);b.angle = 90;b.width = 0.4;b.feather = 1;b.exposure = 1
        for mode in [MaskCombination.intersect,.add,.subtract] {
            b.combination = mode
            let mask = MaskEngine.combinedWeight(b,layers:[a,b],extent:extent)
            let expected:[Float] = mode == .intersect ? [1,0,0,0] : mode == .add ? [1,1,1,0] : [0,0,1,0]
            for (index,point) in [(75,75),(75,25),(25,75),(25,25)].enumerated() { try check(abs(sample(mask,point.0,point.1)-expected[index])<0.002,"Combination quadrant \(mode)") }
        }
        b.combination = .intersect;b.amount = 0.5
        try check(abs(sample(MaskEngine.combinedWeight(b,layers:[a,b],extent:extent),75,75)-0.5)<0.002,"Strength applied more than once")
        b.amount = 1
        let feather = sample(MaskEngine.combinedWeight(b,layers:[a,b],extent:extent),50,50)
        try check(feather>0.2 && feather<0.3,"Combined feather continuity")
        try check(sample(MaskEngine.combinedWeight(b,layers:[b],extent:extent),25,75)>0.99,"First mask missing-parent fallback")
        let source = CIImage(color:CIColor(red:0.18,green:0.18,blue:0.18,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:extent)
        let graded = MaskEngine.apply(source,layers:[a,b])
        try check(abs(sample(graded,75,75)-0.36)<0.003 && abs(sample(graded,25,75)-0.18)<0.003,"Combined adjustment isolation")
        var brush = LocalMask(kind:.brush);brush.enabled = false
        var drawing = BrushDrawing();_ = drawing.begin(point:BrushPoint(x:0.5,y:0.5),radius:0.2,feather:0.5,erase:false);brush.brush = drawing
        var lum = LocalMask(kind:.luminance);lum.selection = MaskSelection(lower:0,upper:1);lum.exposure = 1;lum.combination = .intersect
        let prepared = try BrushMaskRasterizer.prepareExport(layers:[brush,lum],extent:extent)
        let result = BrushMaskRasterizer.$preparedExport.withValue(prepared) { MaskEngine.apply(source,layers:[brush,lum]) }
        try check(abs(sample(result,50,50)-0.36)<0.003 && abs(sample(result,5,5)-0.18)<0.003,"Neutral brush export dependency lost")
        var recipe = Recipe();recipe.masks = [brush,lum]
        try check(try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(recipe)) == recipe,"Combination persistence")
        let old = try JSONDecoder().decode(LocalMask.self,from:JSONEncoder().encode(LocalMask(kind:.linear)))
        try check(old.combination == nil,"Legacy separate default")
        try check(MaskEngine.requiredIndices([brush,lum]) == Set([0,1]),"Export dependency list")
        var third = LocalMask(kind:.luminance);third.selection = MaskSelection(lower:0,upper:1);third.combination = .subtract
        let chain = MaskEngine.combinedWeight(third,layers:[brush,lum,third],extent:extent,reference:source)
        try check(sample(chain,50,50)<0.001 && sample(chain,5,5)>0.99,"Chained coverage")
        for kind in LocalMaskKind.allCases {
            var m = LocalMask(kind:kind);m.width = 0.22;m.amount = 0.2;m.angle = 12;m.exposure = 2
            SliderDefaults.reset(&m,key:\.width);SliderDefaults.reset(&m,key:\.amount);SliderDefaults.reset(&m,key:\.angle);SliderDefaults.reset(&m,key:\.exposure)
            try check(m.width == LocalMask(kind:kind).width && m.amount == 1 && m.angle == LocalMask(kind:kind).angle && m.exposure == 0,"Kind-specific slider defaults")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CombinedExport-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let file = root.appendingPathComponent("source.png")
        try context.writePNGRepresentation(of:source,to:file,format:.RGBA8,colorSpace:ImageEngine.output)
        let bytes = try Data(contentsOf:file),exported = try ImageEngine.export(source:file,recipe:recipe,format:.png)
        defer { try? FileManager.default.removeItem(at:exported.url) }
        let opened = try ImageEngine.open(exported.url).image
        try check(abs(sample(opened,50,50)-0.36)<0.01 && abs(sample(opened,5,5)-0.18)<0.01,"Combined photo export/guide isolation")
        try check(try Data(contentsOf:file) == bytes,"Combined export changed original")
        var reset = lum;reset.selection?.lower = 0.9;reset.selection?.upper = 0.95
        SliderDefaults.resetSelection(&reset,key:\.upper)
        try check(reset.selection?.upper == 0.75 && reset.selection?.lower == 0.75,"Coupled brightness reset")
        return ["passed":true,"intersectAddSubtract":true,"softEdges":true,"strengthOnce":true,"neutralParentSelection":true,"firstMaskFallback":true,"localIsolation":true,"brushExportDependency":true,"chainedSelection":true,"legacyPersistence":true,"kindSpecificReset":true,"validBrightnessReset":true,"photoExportOriginalPreserved":true]
    }
}
#endif
