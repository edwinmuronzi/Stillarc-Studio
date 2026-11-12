#if DEBUG
import Foundation
import CoreImage
import AVFoundation

enum ReferenceMatchVerification {
    static func check(_ yes:Bool,_ message:String) throws {if !yes {throw NSError(domain:"ReferenceQA",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
    static func run() async throws -> [String:Any] {
        let context=ImageEngine.context(),e=CGRect(x:0,y:0,width:64,height:48)
        func image(_ r:Double,_ g:Double,_ b:Double) -> CIImage {CIImage(color:CIColor(red:r,green:g,blue:b,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:e)}
        func pixel(_ image:CIImage) -> [Float] {var p=[Float](repeating:0,count:4);context.render(image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:20,y:20,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p}
        let original=image(0.18,0.20,0.22),target=image(0.22,0.20,0.18)
        let stats=try ShotMatching.statistics(original),ref=try ShotMatching.statistics(target)
        let grade=ShotMatching.suggestion(source:stats,reference:ref,light:true,color:true,richness:false)
        let corrected=pixel(ShotMatching.apply(original,grade)),wanted=pixel(target)
        try check(zip(corrected,wanted).allSatisfy {abs($0-$1)<0.005},"Linear light/color matching incorrect")
        var zero=grade;zero.amount=0
        try check(pixel(ShotMatching.apply(original,zero))==pixel(original) && pixel(ShotMatching.apply(original,nil))==pixel(original),"Neutral match changed pixels")
        var partial=grade;partial.amount=0.5
        let mid=pixel(ShotMatching.apply(original,partial));try check(mid[0]>pixel(original)[0] && mid[0]<corrected[0],"Match strength not intermediate")
        let neutral=ShotMatching.suggestion(source:stats,reference:stats,light:true,color:true,richness:true)
        try check(neutral.isNeutral,"Repeated same-image match not neutral")
        let onlyLight=ShotMatching.suggestion(source:stats,reference:ref,light:true,color:false,richness:false)
        try check(onlyLight.red==1 && onlyLight.green==1 && onlyLight.blue==1 && onlyLight.saturation==1,"Match group isolation")
        let limited=MatchGrade(exposure:99,red:99,green:0,blue:.infinity,saturation:99,amount:99).validated()
        try check(limited.exposure==1.5 && limited.red==1.4 && limited.green==0.7 && limited.blue==1 && limited.saturation==1.25 && limited.amount==1,"Match bounds")
        do {_ = try ShotMatching.statistics(image(0,0,0));throw StudioError.render} catch let err as NSError {try check(err.domain=="ShotMatch","Black reference not rejected")}
        do {_ = try ShotMatching.statistics(CIImage(color:.clear).cropped(to:e));throw StudioError.render} catch let err as NSError {try check(err.domain=="ShotMatch","Transparent reference not rejected")}
        let old=try JSONDecoder().decode(Recipe.self,from:Data("{}".utf8));try check(old==Recipe(),"Old recipe defaults")
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("ReferenceQA-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer {try? FileManager.default.removeItem(at:root)}
        let file=root.appendingPathComponent("source.png"),targetURL=root.appendingPathComponent("target.png")
        try context.writePNGRepresentation(of:original,to:file,format:.RGBA8,colorSpace:ImageEngine.output)
        try context.writePNGRepresentation(of:target,to:targetURL,format:.RGBA8,colorSpace:ImageEngine.output)
        let sourceData=try Data(contentsOf:file),vault=ProjectVault(root:root.appendingPathComponent("vault"))
        var project=try await vault.importPhoto(file),targetProject=try await vault.importPhoto(targetURL)
        let reference=try await vault.importReference(targetURL,project:project)
        var recipe=Recipe();recipe.reference=reference;recipe.matchGrade=grade;project.recipe=recipe
        _ = try await vault.save(project)
        let loaded=try await vault.load().0.first(where:{$0.id==project.id})!
        try check(loaded.recipe==recipe,"Reference/match persistence")
        let source=await vault.source(project),stored=source.deletingLastPathComponent().appendingPathComponent(reference.filename)
        let bytes=try Data(contentsOf:stored)
        targetProject.recipe.exposure=0.4;_ = try await vault.save(targetProject)
        let snapshot=try await vault.referenceSnapshot(targetProject,for:project)
        try check(snapshot.id != reference.id && (try Data(contentsOf:stored))==bytes,"Reference snapshot mutated previous reference")
        let before=pixel(try ImageEngine.open(source).image)
        let output=try ImageEngine.export(source:source,recipe:recipe,format:.png);defer {try? FileManager.default.removeItem(at:output.url)}
        let after=pixel(try ImageEngine.open(output.url).image)
        let expected=pixel(ImageEngine.apply(try ImageEngine.open(source).image,recipe:recipe))
        try check(zip(after,expected).allSatisfy {abs($0-$1)<0.006} && abs(after[0]-before[0])>0.02,"Match preview/export mismatch")
        let copy=recipe.colorPreset
        try check(copy.reference==nil && copy.matchGrade==grade && PresetDocument(name:"Match",recipe:copy).schema==4,"Portable match schema/isolation")
        let reopened=try JSONDecoder().decode(PresetDocument.self,from:JSONEncoder().encode(PresetDocument(name:"Match",recipe:copy)))
        try check(reopened.recipe==copy,"Matched preset roundtrip")
        var destination=Recipe();destination.reference=snapshot
        let pasted=destination.pasting(recipe,sections:[.color])
        try check(pasted.reference==snapshot && pasted.matchGrade==grade && destination.pasting(recipe,sections:[.light]).matchGrade==nil,"Transfer reference isolation")
        var reset=recipe;reset.reset(.color)
        try check(reset.matchGrade==nil && reset.reference==reference && recipe.hasAdjustments(in:.color),"Match reset/dot")
        try check(try Data(contentsOf:file)==sourceData,"Original changed")
        let d=SkinHueGuide.direction
        try check(d.dx<0 && d.dy<0 && abs(hypot(d.dx,d.dy)-1)<0.00001,"Skin guide projection")
        var videoResult:[String:Any]=[:]
        let movie=try await VideoFixtures.make(profile:.standard,frames:12,audioTracks:1,width:320,height:240)
        defer {try? FileManager.default.removeItem(at:movie.deletingLastPathComponent())}
        let desc=try await VideoEngine.describe(movie)
        var vr=Recipe();vr.matchGrade=MatchGrade(exposure:0.3,red:1.1,green:0.96,blue:0.9,saturation:1.05);vr.video.start=0.1
        let frame=try await VideoEngine.poster(movie,descriptor:desc,maxDimension:320,time:0.1)
        try check(pixel(ShotMatching.preview(frame,recipe:vr)).allSatisfy(\.isFinite),"Trimmed frame matching invalid")
        let video=try await VideoEngine.export(source:movie,descriptor:desc,recipe:vr,privacy:ExportPrivacy(),progress:{_ in})
        defer {try? FileManager.default.removeItem(at:video.url)}
        let result=try await VideoEngine.describe(video.url),rendered=try await VideoEngine.poster(video.url,descriptor:result,maxDimension:320)
        let a=RealMediaVerification.samples(ShotMatching.preview(frame,recipe:vr)),b=RealMediaVerification.samples(rendered.image)
        let delta=zip(a,b).map {abs(Double($0-$1))}.reduce(0,+)/Double(a.count)
        try check(delta<0.035 && result.width==320 && result.height==240 && abs(result.duration-(desc.duration-0.1))<0.04,"Video match export timing/color")
        let audio=try await AVURLAsset(url:video.url).loadTracks(withMediaType:.audio);try check(audio.count==1,"Matched export lost audio")
        videoResult=["passed":true,"previewExportMeanError":delta,"duration":result.duration,"audioTracks":audio.count]
        return ["passed":true,"linearLightAndColor":true,"strengthAndBounds":true,"emptyReferenceGuard":true,"privateReferencePersistenceAndSnapshot":true,"PNGMatch":true,"presetSchema4":true,"transferResetIsolation":true,"skinGuideProjection":true,"sourcePreserved":true,"video":videoResult,"emptyBin":try await EmptyBinVerification.run()]
    }
    @MainActor static func writeReport() async {
        let file=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("reference-match-verification.json")
        try? FileManager.default.removeItem(at:file)
        do {var report=try await Task.detached {try await run()}.value;report["version"]=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String;report["thermal"]=ProcessInfo.processInfo.thermalState.rawValue;try JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:file,options:.atomic)}
        catch {try? JSONSerialization.data(withJSONObject:["passed":false,"error":error.localizedDescription],options:.prettyPrinted).write(to:file,options:.atomic)}
    }
}
#endif
