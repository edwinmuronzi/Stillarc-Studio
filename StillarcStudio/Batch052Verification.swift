#if DEBUG
import CoreImage
import AVFoundation

enum Batch052Verification {
    static func check(_ value:Bool,_ text:String) throws {try Finish049Verification.check(value,text)}
    static func matte(duration:Double=2)->AutomaticMask {
        let e=CGRect(x:0,y:0,width:64,height:48),image=CIImage(color:.black).cropped(to:e)
        let png=ImageEngine.context().pngRepresentation(of:image,format:.L8,colorSpace:CGColorSpace(name:CGColorSpace.linearGray)!,options:[:])!
        let frames=(0..<Int(duration*30)).map {TemporalMatte.Frame(id:UUID(),time:Double($0)/30,png:png,width:64,height:48)}
        let t=try! TemporalMatte(start:0,end:duration,sourceDuration:duration,sourceWidth:320,sourceHeight:240,input:InputConversion(),frames:frames,reviewTimes:[0.5,1.5].filter {$0<duration})
        return .init(id:frames[0].id,png:png,width:64,height:48,framing:MaskMotion.signature(Recipe()),videoStart:0,temporal:t,selectionMode:.people)
    }
    static func layer(duration:Double=2)->LocalMask {
        var layer=LocalMask(kind:.subject);layer.automatic=matte(duration:duration);layer.label="People video matte";layer.cutout=true
        var r=VideoMaskRepairs();var point=VideoMaskRepairPoint(time:0)
        _ = point.add.begin(point:.init(x:0.5,y:0.5),radius:0.15,feather:0.1,erase:false)
        r.points=[point,VideoMaskRepairPoint(time:min(1,duration-0.01))];layer.videoRepairs=r;return layer
    }
    static func math() throws ->[String:Any] {
        var recipe=Recipe();recipe.masks=[layer()];recipe.background=PhotoBackground(mode:.solid,red:0,green:0,blue:1)
        let e=CGRect(x:0,y:0,width:320,height:240)
        func pixel(_ t:Double,_ r:Recipe)->Float {MaskMotion.$frame.withValue(.init(time:t,framing:MaskMotion.signature(r))) {Finish049Verification.sample(MaskEngine.weight(r.masks[0],extent:e,framing:MaskMotion.signature(r)),x:160,y:120)[0]}}
        try check(pixel(0,recipe)>0.98 && abs(pixel(0.5,recipe)-0.5)<0.03 && pixel(1,recipe)<0.01,"Repair add/fade/empty-point rendering")
        var subtract=recipe;subtract.masks[0].videoRepairs?.points.removeLast();let addDrawing=subtract.masks[0].videoRepairs!.points[0].add;subtract.masks[0].videoRepairs?.points[0].subtract=addDrawing
        try check(pixel(0,subtract)<0.01,"Subtract must remove overlapping Add")
        let decoded=try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(recipe));try check(decoded==recipe,"Repair recipe persistence")
        var crop=recipe;crop.crop = .square;try check(pixel(0,crop)>0.98,"Repair full-source crop projection")
        var broken=VideoMaskRepairs();broken.points=[.init(time:1),.init(time:0)]
        do {_ = try JSONDecoder().decode(VideoMaskRepairs.self,from:JSONEncoder().encode(broken));throw PointSampling.failure("Invalid repairs accepted")} catch let e as NSError {try check(e.domain != "PointSample","Repair decode bounds")}
        var protected=Recipe();protected.matchGrade=MatchGrade(exposure:0.6,red:1.2,green:0.9,blue:0.8,saturation:1.1,amount:0.5)
        let stats=ShotMatching.Statistics(median:0.3,red:0.2,green:0.3,blue:0.4,saturation:0.5)
        let matched=PoolLookMatching.grade(protected,from:Recipe(),source:stats,referenceStats:stats,protectLight:true,protectWB:true)
        try check(abs(matched.matchGrade!.exposure-0.3)<0.000001 && abs(matched.matchGrade!.red-1.1)<0.000001 && abs(matched.matchGrade!.blue-0.9)<0.000001,"Pool protection lost prior effective brightness/WB matching")
        let original=recipe.masks[0].automatic!.temporal!,old=original.frames
        let patch=try TemporalMatte(start:0.5,end:1,sourceDuration:2,sourceWidth:320,sourceHeight:240,input:InputConversion(),frames:old.filter {$0.time>=0.5 && $0.time<1}.map {.init(id:UUID(),time:$0.time,png:$0.png,width:$0.width,height:$0.height)},reviewTimes:[0.7])
        let replaced=original.replacing(patch,interval:0.5...1)!
        try check(replaced.frames.count==old.count && replaced.frames.filter {$0.time<0.5 || $0.time>=1}.map(\.id)==old.filter {$0.time<0.5 || $0.time>=1}.map(\.id),"Section repair changed outside frames")
        try check(replaced.reviewTimes==[0.7,1.5],"Section repair review markers")
        let context=ImageEngine.context(),white=CIImage(color:.white).cropped(to:e),black=CIImage(color:.black).cropped(to:e),same=Finish049Verification.image([0.2,0.2,0.2],size:e.size)
        let cg=context.createCGImage(same,from:e,format:.RGBA8,colorSpace:ImageEngine.output)!
        let stable=white.cropped(to:CGRect(x:80,y:60,width:160,height:120)).composited(over:black)
        let flash=white.cropped(to:CGRect(x:72,y:56,width:176,height:128)).composited(over:black)
        let a=try MatteEdgeStabilizer.frame(time:0,mask:stable,source:cg,context:context),b=try MatteEdgeStabilizer.frame(time:1.0/30,mask:flash,source:cg,context:context),c=try MatteEdgeStabilizer.frame(time:2.0/30,mask:stable,source:cg,context:context)
        let fixed=MatteEdgeStabilizer.image(previous:a,current:b,next:c)
        let before=Finish049Verification.sample(flash,x:74,y:120)[0],after=Finish049Verification.sample(fixed,x:74,y:120)[0]
        try check(before>0.99 && after<0.25,"Stabilizer did not suppress single-frame contour flash: \(after)")
        try check(Finish049Verification.sample(fixed,x:160,y:120)[0]>0.98,"Stabilizer damaged stable centre")
        let changedGuide=white.cropped(to:CGRect(x:72,y:56,width:176,height:128)).composited(over:same)
        let changedCG=context.createCGImage(changedGuide,from:e,format:.RGBA8,colorSpace:ImageEngine.output)!
        let genuine=try MatteEdgeStabilizer.frame(time:1.0/30,mask:flash,source:changedCG,context:context)
        try check(Finish049Verification.sample(MatteEdgeStabilizer.image(previous:a,current:genuine,next:c),x:74,y:120)[0]>0.98,"Stabilizer erased changing image detail")
        return ["passed":true,"repairAddSubtractFade":true,"cropAndPersistence":true,"invalidRepairRejected":true,"sectionIsolation":true,"reviewHints":true,"priorMatchBalancePreserved":true,"changingDetailPreserved":true,"contourFlashBefore":before,"contourFlashAfter":after]
    }
    static func poolAndExport() async throws ->[String:Any] {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("Batch052-\(UUID())"),vault=ProjectVault(root:root.appendingPathComponent("vault"))
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer {try? FileManager.default.removeItem(at:root)}
        let image=root.appendingPathComponent("source.png")
        try ImageEngine.context().writePNGRepresentation(of:Finish049Verification.image([0.2,0.3,0.4]),to:image,format:.RGBA8,colorSpace:ImageEngine.output)
        var reference=try await vault.importPhoto(image);reference.recipe.look = .bluehour;reference.recipe.exposure=0.6;reference.recipe.warmth=0.2;reference=try await vault.save(reference)
        var target=try await vault.importPhoto(image);target.recipe.exposure = -0.3;target.recipe.warmth = -0.2;target.recipe.tint=0.15;target.recipe.masks=[LocalMask(kind:.radial)];target=try await vault.save(target)
        let changes=try await PoolLookMatching.prepare(reference:reference,targets:[target],vault:vault,protectLight:true,protectWB:true,progress:{_ in})
        try check(changes.count==1 && changes[0].after.exposure==target.recipe.exposure && changes[0].after.warmth==target.recipe.warmth && changes[0].after.tint==target.recipe.tint && changes[0].after.masks==target.recipe.masks,"Pool match overwrote individual source settings")
        try check(changes[0].after.matchGrade?.exposure==0 && changes[0].after.matchGrade?.red==1,"Protected pool match changed brightness/WB correction")
        let saved=try await vault.commitPoolMatch(changes);try check(saved[0].versions?.last?.name=="Before pool match","Pool match version checkpoint")
        let step=PoolHistoryStep(title:"Match pool look",changes:changes)
        let undone=try await vault.applyPoolHistory(step,undo:true),redone=try await vault.applyPoolHistory(step,undo:false)
        try check(undone[0].recipe==target.recipe && redone[0].recipe==changes[0].after,"Whole pool match undo/redo")
        var second=try await vault.importPhoto(image),otherAfter=Recipe();otherAfter.saturation=0.2
        let secondBefore=second.recipe;second.recipe.exposure=0.1;second=try await vault.save(second)
        var candidateAfter=redone[0].recipe;candidateAfter.saturation+=0.05
        var rejected=false
        do {_ = try await vault.commitPoolMatch([.init(id:target.id,before:redone[0].recipe,after:candidateAfter),.init(id:second.id,before:secondBefore,after:otherAfter)])} catch {rejected=true}
        let unchanged=try await vault.load().0.first {$0.id==target.id}
        try check(rejected && unchanged?.recipe==redone[0].recipe && unchanged?.versions?.count==redone[0].versions?.count,"Stale pool target allowed partial commit")
        let cancelled=Task.detached {try await PoolLookMatching.prepare(reference:reference,targets:[target],vault:vault,protectLight:true,protectWB:true,progress:{_ in})};cancelled.cancel()
        do {_ = try await cancelled.value;throw PointSampling.failure("Pool cancellation ignored")} catch is CancellationError {}
        let clip=try await VideoFixtures.make(profile:.standard,frames:60,audioTracks:1,width:320,height:240,linear:[1,0,0]);defer {try? FileManager.default.removeItem(at:clip.deletingLastPathComponent())}
        let descriptor=try await VideoEngine.describe(clip);var r=Recipe();r.masks=[layer()];r.background=PhotoBackground(mode:.solid,red:0,green:0,blue:1)
        let exported=try await VideoEngine.export(source:clip,descriptor:descriptor,recipe:r,progress:{_ in});defer {try? FileManager.default.removeItem(at:exported.url)}
        let info=try await VideoEngine.describe(exported.url),a=try await VideoEngine.poster(exported.url,descriptor:info,maxDimension:320,time:0),b=try await VideoEngine.poster(exported.url,descriptor:info,maxDimension:320,time:1.2)
        try check(Finish049Verification.sample(a.image,x:160,y:120)[0]>0.8 && Finish049Verification.sample(b.image,x:160,y:120)[2]>0.8,"Encoded source-time repair differs from preview")
        var p=try await vault.importPhoto(clip);p.recipe=r;p=try await vault.save(p)
        let archive=try await vault.writeArchive([p.id]);defer {try? FileManager.default.removeItem(at:archive.deletingLastPathComponent())}
        let restored=try await vault.restoreArchive(archive);try check(restored[0].recipe==r,"Repair source backup")
        return ["passed":true,"protectedPoolMatch":true,"poolUndoRedo":true,"poolVersion":true,"staleTargetAtomicPreflight":true,"cancellation":true,"encodedTimedRepairs":true,"backupRepairs":true]
    }
    @MainActor static func writeReport() async {
        let docs=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0],url=docs.appendingPathComponent("batch-052-verification.json")
        try? FileManager.default.removeItem(at:url)
        do {let result=try await Task.detached(priority:.utility){["math":try math(),"integration":try await poolAndExport(),"passed":true,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","thermal":ProcessInfo.processInfo.thermalState.rawValue] as [String:Any]}.value;try JSONSerialization.data(withJSONObject:result,options:.prettyPrinted).write(to:url,options:.atomic)}
        catch {try? JSONSerialization.data(withJSONObject:["passed":false,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","error":error.localizedDescription],options:.prettyPrinted).write(to:url,options:.atomic)}
    }
}
#endif
