#if DEBUG
import Foundation
import CoreImage
import AVFoundation

enum VideoAnimationVerification {
    static func run() async throws ->[String:Any] {
        func check(_ ok:Bool,_ message:String) throws {if !ok {throw ProjectArchive.fail("Animation QA: "+message)}}
        VerificationProgress.record("Animation math start")
        var track=AnimationTrack(target:.exposure);track.points=[AnimationPoint(time:0,value:0),AnimationPoint(time:1,value:1)]
        try check(track.value(at:-1)==0 && track.value(at:2)==1 && abs(track.value(at:0.25)-0.15625)<0.000001,"Smooth easing/held ends")
        track.blend = .linear;try check(abs(track.value(at:0.25)-0.25)<0.000001,"Linear interpolation")
        track.enabled=false;try check(track.value(at:0.5)==0,"Disabled track")
        track.enabled=true;track.points=[AnimationPoint(time:1,value:9),AnimationPoint(time:0,value:0),AnimationPoint(time:.nan,value:1),AnimationPoint(time:1,value:2)]
        track=track.validated();try check(track.points.count==2 && track.points[0].time==0 && track.points[1].value==3,"Bounds, sorting and duplicate times")
        let context=ImageEngine.context(),image=CIImage(color:CIColor(red:0.2,green:0.2,blue:0.2,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:CGRect(x:0,y:0,width:64,height:48))
        func pixel(_ image:CIImage)->[Float] {var v=[Float](repeating:0,count:4);context.render(image,toBitmap:&v,rowBytes:16,bounds:CGRect(x:image.extent.midX,y:image.extent.midY,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return v}
        var r=Recipe();r.exposure=0.25
        var exposure=AnimationTrack(target:.exposure);exposure.points=[AnimationPoint(time:0,value:0),AnimationPoint(time:1,value:1)]
        r.videoAnimation=VideoAnimation(tracks:[exposure])
        let math=MaskMotion.$frame.withValue(.init(time:0.5,framing:MaskMotion.signature(r))){HDRPipeline.grade(image,recipe:r,hdr:false)}
        try check(abs(pixel(math)[0]-Float(0.2*pow(2,0.75)))<0.008,"Rendered frame exposure")
        let bright=CIImage(color:CIColor(red:1.5,green:1.5,blue:1.5,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:image.extent)
        let hdr=MaskMotion.$frame.withValue(.init(time:0.5,framing:MaskMotion.signature(r))){HDRPipeline.grade(bright,recipe:r,hdr:true)}
        try check(abs(pixel(hdr)[0]-Float(1.5*pow(2,0.75)))<0.04,"HDR animation headroom")
        try check(VideoAnimation.resolve(r,time:nil)==r,"Absent time bypass")
        let resolved=VideoAnimation.resolve(r,time:0.5)
        try check(resolved.videoAnimation==nil && VideoAnimation.resolve(resolved,time:0.5)==resolved,"Double application")
        var reset=r;reset.reset(.light);try check(reset.videoAnimation?.tracks.isEmpty==true && r.hasAdjustments(in:.light),"Light reset/dot")
        try check(r.colorPreset.videoAnimation==nil && Recipe().pasting(r,sections:Set(AdjustmentSection.allCases)).videoAnimation==nil,"Preset/clipboard isolation")
        let decoded=try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(r));try check(decoded==r && JSONDecoder().decode(Recipe.self,from:Data("{}".utf8)).videoAnimation==nil,"Recipe compatibility")
        VerificationProgress.record("Animation encode start")
        let movie=try await VideoFixtures.make(profile:.standard,frames:60,audioTracks:1,width:320,height:240)
        defer {try? FileManager.default.removeItem(at:movie.deletingLastPathComponent())}
        let descriptor=try await VideoEngine.describe(movie)
        var video=Recipe();video.video.start=0.2;video.video.end=1.4;video.rotation=1;video.look = .daylight;video.lookAmount=0.8
        video.lut=try LUTVerification.example(dimension:33);video.lutAmount=0.25
        var mask=LocalMask(kind:.radial);mask.exposure=0.4
        mask.motion=MaskMotion(framing:MaskMotion.signature(video),start:0,end:2,points:[.init(time:0,x:0,y:0),.init(time:2,x:0.1,y:0)])
        mask.motion?.setCorrection(time:0,x:0,y:0,tolerance:0.001);mask.motion?.setCorrection(time:1.3,x:0.1,y:-0.1,tolerance:0.001)
        video.masks=[mask]
        func fade(_ target:AnimationTarget,_ a:Double,_ b:Double)->AnimationTrack {var t=AnimationTrack(target:target);t.points=[AnimationPoint(time:0.2,value:a),AnimationPoint(time:1.3,value:b)];return t}
        video.videoAnimation=VideoAnimation(tracks:[fade(.exposure,-0.5,0.5),fade(.look,0,1),fade(.lut,1,0),fade(.mask(mask.id),0,1)])
        let output=try await VideoEngine.export(source:movie,descriptor:descriptor,recipe:video,progress:{_ in})
        defer {try? FileManager.default.removeItem(at:output.url)}
        let out=try await VideoEngine.describe(output.url),audio=try await AVURLAsset(url:output.url).loadTracks(withMediaType:.audio)
        try check(out.width==240 && out.height==320 && abs(out.duration-1.2)<0.04 && audio.count==1,"Video orientation/trim/audio")
        var errors:[Float]=[]
        for seconds in [0.0,0.4,0.9] {
            let source=try await VideoEngine.poster(movie,descriptor:descriptor,maxDimension:320,time:seconds+0.2)
            let fixed=VideoAnimation.resolve(video,time:seconds+0.2)
            let expected=MaskMotion.$frame.withValue(.init(time:seconds+0.2,framing:MaskMotion.signature(fixed))){HDRPipeline.grade(source.image,recipe:fixed,hdr:false)}
            let actual=try await VideoEngine.poster(output.url,descriptor:out,maxDimension:320,time:seconds)
            let error=zip(pixel(expected),pixel(actual.image)).map {abs($0-$1)}.max() ?? 99;errors.append(error)
            try check(error<0.035,"Animated preview/export mismatch at \(seconds): \(error)")
        }
        var trimmed=video;trimmed.video.start=0.6
        try check(abs(VideoAnimation.resolve(trimmed,time:0.6).exposure-VideoAnimation.resolve(video,time:0.6).exposure)<0.000001,"Trim changed source-time animation")
        let neutralMask=VideoAnimation.resolve(video,time:0.2),fullMask=VideoAnimation.resolve(video,time:1.3)
        try check(neutralMask.masks[0].amount==0 && fullMask.masks[0].amount==1 && video.masks[0].amount==1,"Mask strength/base preservation")
        VerificationProgress.record("Animation persistence start")
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("AnimationPersist-\(UUID())"),vault=ProjectVault(root:folder)
        defer {try? FileManager.default.removeItem(at:folder)}
        var project=try await vault.importPhoto(movie);project.recipe=video;project=try await vault.save(project)
        let version=EditVersion(name:"Animated");try await vault.saveVersion(project,version:version,recipe:video)
        project.versions=[version];project=try await vault.save(project)
        let stored=try await vault.loadVersion(project,version:version);try check(stored.masks==video.masks && stored.videoAnimation==video.videoAnimation,"Version persistence")
        let loaded=try await vault.load().0.first!;try check(loaded.recipe.videoAnimation==video.videoAnimation,"Reopen persistence")
        let blob=try JSONEncoder().encode(loaded);let same=try JSONDecoder().decode(Project.self,from:blob);try check(same.recipe.videoAnimation==video.videoAnimation,"Queue snapshot serialization")
        VerificationProgress.record("Animation backup start")
        let package=try await vault.writeArchive([project.id]);defer {try? FileManager.default.removeItem(at:package.deletingLastPathComponent())}
        let manifest=try ProjectArchive.inspect(package);try check(manifest.minimumReader==41,"Backup reader version")
        let restored=try await vault.restoreArchive(package);try check(restored[0].recipe.masks==video.masks && restored[0].recipe.videoAnimation==video.videoAnimation,"Animated backup")
        VerificationProgress.record("Animated queue start")
        let queue=await MainActor.run {StudioExportQueue(vault:vault,root:folder.appendingPathComponent("delivery-queue"))}
        let added=await queue.enqueue([project],format:.jpeg,privacy:ExportPrivacy(),delivery:DeliverySettings());try check(added,"Animated queue enqueue")
        await queue.start();await queue.waitUntilIdle();let jobs=await queue.jobs
        try check(jobs[0].state == .completed,"Animated queue completion")
        let queuedURLs=await queue.urls(jobs[0]),queuedDescriptor=try await VideoEngine.describe(queuedURLs[0])
        let queuedFrame=try await VideoEngine.poster(queuedURLs[0],descriptor:queuedDescriptor,maxDimension:320,time:0.4)
        let directFrame=try await VideoEngine.poster(output.url,descriptor:out,maxDimension:320,time:0.4)
        try check(zip(pixel(queuedFrame.image),pixel(directFrame.image)).allSatisfy {abs($0-$1)<0.01},"Animated queue/direct agreement")
        VerificationProgress.record("Animation all checks passed")
        return ["passed":true,"interpolationBoundsAndHolding":true,"pixelExposureAndSingleApplication":true,"HDRHeadroom":true,"maskLookLUTFades":true,"sourceTimeTrim":true,"videoOrientationAudio":true,"previewExportErrors":errors,"resetPresetTransferIsolation":true,"projectVersionQueuePersistence":true,"animatedBackupAndQueueExport":true]
    }
    static func writeReport() async {
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("video-animation-verification.json")
        try? FileManager.default.removeItem(at:url)
        let result=await Task.detached(priority:.utility){()->[String:Any] in do {return try await run()} catch {return ["passed":false,"error":error.localizedDescription]}}.value
        var report=result;report["version"]=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String;report["thermal"]=ProcessInfo.processInfo.thermalState.rawValue
        if let data=try? JSONSerialization.data(withJSONObject:report,options:.prettyPrinted){try? data.write(to:url,options:.atomic)}
    }
}
#endif
