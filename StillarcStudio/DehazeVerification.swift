#if DEBUG
import CoreImage
import Foundation

enum DehazeVerification {
    static func run() throws -> [String:Any] {
        func check(_ value:Bool,_ message:String) throws { if !value { throw NSError(domain:"DehazeQA",code:1,userInfo:[NSLocalizedDescriptionKey:message]) } }
        try DehazeRendering.prepare()
        let context = ImageEngine.context(),bounds = CGRect(x:0,y:0,width:320,height:180)
        func gray(_ value:Double) -> CIImage { CIImage(color:CIColor(red:value,green:value,blue:value,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:bounds) }
        func pixel(_ image:CIImage) -> [Float] { var p = [Float](repeating:0,count:4);context.render(image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:120,y:90,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p }
        let source = gray(0.5)
        try check(DehazeRendering.apply(source,amount:0) === source,"Neutral Dehaze did not bypass processing")
        let removed = pixel(DehazeRendering.apply(source,amount:1))[0],added = pixel(DehazeRendering.apply(source,amount:-1))[0]
        try check(abs(removed-Float((0.5-0.325)/0.675))<0.003 && abs(added-Float(0.68/1.18))<0.003,"Veil direction/reference values")
        let a = pixel(DehazeRendering.apply(gray(0.65),amount:1))[0],b = pixel(DehazeRendering.apply(gray(0.75),amount:1))[0]
        try check(b-a>0.11,"Washed-out bright tones did not gain separation")
        try check(pixel(DehazeRendering.apply(gray(0),amount:1))[0]<0.0001,"Clear black was crushed below zero")
        for amount in [-1.0,1.0] {
            try check(abs(pixel(DehazeRendering.apply(gray(1),amount:amount))[0]-1)<0.001,"White protection")
            try check(abs(pixel(DehazeRendering.apply(gray(4),amount:amount))[0]-4)<0.01,"Uniform HDR headroom clipped")
        }
        let transparent = CIImage(color:CIColor(red:0.5,green:0.4,blue:0.3,alpha:0.5,colorSpace:ImageEngine.working)!).cropped(to:bounds)
        let alpha = pixel(DehazeRendering.apply(transparent,amount:0.7))[3];try check(abs(alpha-0.5)<0.001,"Alpha changed")
        var recipe = Recipe();recipe.dehaze = 0.65
        let decoded = try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(recipe))
        try check(decoded == recipe && recipe.colorPreset.dehaze == 0.65 && recipe.hasAdjustments(in:.detail),"Save/preset/indicator")
        try check(Recipe().pasting(recipe,sections:[.detail]).dehaze == 0.65,"Detail copy/paste")
        var reset = recipe;reset.reset(.detail);try check(reset.dehaze == 0,"Dehaze reset")
        let old = try JSONDecoder().decode(Recipe.self,from:Data("{}".utf8));try check(old.dehaze == 0,"Legacy default")
        var invalid = Recipe();invalid.dehaze = .nan;try check(invalid.validated().dehaze == 0,"Numeric validation")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("DehazeQA-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer { try? FileManager.default.removeItem(at:root) }
        let url = root.appendingPathComponent("source.png");try context.writePNGRepresentation(of:source,to:url,format:.RGBA8,colorSpace:ImageEngine.output)
        let bytes = try Data(contentsOf:url),opened = try ImageEngine.open(url)
        let expected = pixel(ImageEngine.apply(opened.image,recipe:recipe))[0]
        let result = try ImageEngine.export(source:url,recipe:recipe,format:.png);defer { try? FileManager.default.removeItem(at:result.url) }
        let actual = pixel(try ImageEngine.open(result.url).image)[0]
        try check(abs(actual-expected)<0.008 && (try Data(contentsOf:url)) == bytes,"Export differs from preview or changed source")
        return ["passed":true,"analyticReferences":true,"positiveAndNegative":true,"whiteBlackAndHDR":true,"alphaPreserved":true,"neutralBypass":true,"persistenceResetCopyPaste":true,"legacyDefaults":true,"photoExportMatches":true,"sourcePreserved":true]
    }
}
#endif
