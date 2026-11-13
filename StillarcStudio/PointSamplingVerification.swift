#if DEBUG
import CoreImage
import Foundation

enum PointSamplingVerification {
    static func fixture() throws ->URL {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent("PointPicker-\(UUID()).png")
        let image=CIImage(color:CIColor(red:0.31,green:0.3,blue:0.28,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:CGRect(x:0,y:0,width:720,height:960))
        try ImageEngine.context().writePNGRepresentation(of:image,to:url,format:.RGBA16,colorSpace:ImageEngine.output)
        return url
    }
    static func run() throws ->[String:Any] {
        func check(_ b:Bool,_ s:String) throws {if !b {throw PointSampling.failure("Sampling QA: "+s)}}
        let context=ImageEngine.context(),extent=CGRect(x:0,y:0,width:120,height:100)
        func image(_ rgb:[Double],alpha:Double=1)->CIImage {CIImage(color:CIColor(red:rgb[0],green:rgb[1],blue:rgb[2],alpha:alpha,colorSpace:ImageEngine.working)!).cropped(to:extent)}
        func pixel(_ image:CIImage)->[Float] {var v=[Float](repeating:0,count:4);context.render(image,toBitmap:&v,rowBytes:16,bounds:CGRect(x:10,y:10,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return v}
        let start=Date();var worst=0.0
        for rgb in [[0.3,0.3,0.3],[0.31,0.3,0.28],[0.28,0.3,0.31],[0.3,0.29,0.3]] {
            let r=try PointSampling.solve(rgb+[1],tool:.whiteBalance,recipe:Recipe())
            var recipe=Recipe();PointSampling.apply(r,to:&recipe)
            let result=pixel(ImageEngine.apply(image(rgb),recipe:recipe)),high=result.prefix(3).max()!,low=result.prefix(3).min()!
            worst=max(worst,Double((high-low)/high))
            try check(worst<0.02,"Neutral balance failed \(rgb) \(recipe.warmth) \(recipe.tint) \(result)")
            let reopened=try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(recipe));try check(reopened==recipe,"Picker persistence")
        }
        let patch=image([0.2,0.2,0.2]),mean=PointSampling.mean(patch,point:CGPoint(x:0.5,y:0.5))
        try check(abs(mean[0]-0.2)<0.001,"Linear patch average")
        var recipe=Recipe();recipe.levelGamma=1.4;recipe.levelOutputBlack=0.1
        let black=try PointSampling.solve(mean,tool:.blackPoint,recipe:recipe);PointSampling.apply(black,to:&recipe)
        try check(abs(recipe.levelBlack-0.2)<0.001 && recipe.levelGamma==1.4 && recipe.levelOutputBlack==0.1,"Black picker erased unrelated Levels")
        let white=try PointSampling.solve([0.8,0.8,0.8,1],tool:.whitePoint,recipe:recipe);PointSampling.apply(white,to:&recipe)
        try check(abs(recipe.levelWhite-0.8)<0.001,"White picker")
        var endpoints=recipe;endpoints.levelGamma=1;endpoints.levelOutputBlack=0
        let low=pixel(ImageEngine.apply(image([0.2,0.2,0.2]),recipe:endpoints)),high=pixel(ImageEngine.apply(image([0.8,0.8,0.8]),recipe:endpoints))
        try check(abs(low[0])<0.002 && abs(high[0]-1)<0.002,"Levels endpoints mismatch")
        for pair in [([0.2,0.2,0.2,0.2],PointSampleTool.whiteBalance),([1,1,1,1],.whiteBalance),([0,0,0,1],.whiteBalance),([Double.nan,0.2,0.2,1],.blackPoint)] {
            do {_ = try PointSampling.solve(pair.0,tool:pair.1,recipe:Recipe());throw NSError(domain:"UnexpectedSample",code:1)} catch let e as NSError {try check(e.domain=="PointSample","Invalid sample accepted")}
        }
        do {_ = try PointSampling.solve([0.9,0.9,0.9,1],tool:.blackPoint,recipe:recipe);throw NSError(domain:"UnexpectedSample",code:2)} catch let e as NSError {try check(e.domain=="PointSample","Crossed Levels accepted")}
        let top=CIImage(color:CIColor(red:0.7,green:0.7,blue:0.7,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:CGRect(x:0,y:50,width:120,height:50)).composited(over:image([0.1,0.1,0.1]))
        try check(PointSampling.mean(top,point:CGPoint(x:0.5,y:0.1))[0]>PointSampling.mean(top,point:CGPoint(x:0.5,y:0.9))[0]+0.4,"Top-origin tap mapping")
        var before=Recipe();before.crop = .square;before.exposure=0.5;before.warmth=0.3;before.levelBlack=0.2;before.look = .ember
        let wb=PointSampling.reference(patch,recipe:before,stage:.whiteBalance,hdr:false)
        try check(abs(pixel(wb)[0]-Float(0.2*sqrt(2)))<0.002 && wb.extent.width==wb.extent.height,"WB sampling stage/crop")
        var withoutLevels=before;withoutLevels.levelBlack=0;withoutLevels.look = .original
        let levels=PointSampling.reference(patch,recipe:before,stage:.levels,hdr:false)
        try check(zip(pixel(levels),pixel(ImageEngine.apply(patch,recipe:withoutLevels))).allSatisfy {abs($0-$1)<0.001},"Levels sampled downstream colour")
        let hdr=PointSampling.reference(image([2,2,2]),recipe:Recipe(),stage:.levels,hdr:true)
        try check(abs(pixel(hdr)[0]-1)<0.002,"HDR normalization")
        return ["passed":true,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","maxNeutralError":worst,"elapsedMilliseconds":Date().timeIntervalSince(start)*1000,"patchAndOrientation":true,"stagesCropHDR":true,"levelsEndpointsAndPreservation":true,"invalidSamplesRejected":true,"legacyRecipePersistence":true]
    }
    @MainActor static func writeReport() async {
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("point-sampling-verification.json")
        do {let report=try await Task.detached(priority:.utility){try run()}.value;try JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:url,options:.atomic)}
        catch {try? JSONSerialization.data(withJSONObject:["passed":false,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","error":error.localizedDescription],options:.prettyPrinted).write(to:url,options:.atomic)}
    }
}
#endif
