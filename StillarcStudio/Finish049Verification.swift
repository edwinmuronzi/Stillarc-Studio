#if DEBUG
import AVFoundation
import CoreImage
import ImageIO
import Foundation
import Vision

enum Finish049Verification {
    static func check(_ b:Bool,_ s:String) throws {if !b {throw NSError(domain:"Finish049QA",code:1,userInfo:[NSLocalizedDescriptionKey:s])}}
    static func sample(_ image:CIImage,x:Double=8,y:Double=8)->[Float] {
        var p=[Float](repeating:0,count:4);ImageEngine.context().render(image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:x,y:y,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p
    }
    static func image(_ rgb:[Double],size:CGSize=CGSize(width:64,height:32))->CIImage {CIImage(color:CIColor(red:rgb[0],green:rgb[1],blue:rgb[2],alpha:1,colorSpace:ImageEngine.working)!).cropped(to:CGRect(origin:.zero,size:size))}
    static func math() throws ->[String:Any] {
        _ = try LogVerification.run();_ = try TrackingVerification.math()
        do {try DeliveryStorage.validate(available:0,planned:1_000_000);throw NSError(domain:"UnexpectedStorage",code:1)} catch let e as NSError {try check(e.domain=="DeliveryStorage","Low-storage preflight")}
        try DeliveryStorage.validate(available:nil,planned:1_000_000);try DeliveryStorage.validate(available:100_000_000,planned:1_000_000)
        let base=image([0.5,0.5,0.5])
        let decoded=sample(LogConversion.apply(base,input:.init(profile:.encodedSRGB,softHighlights:false)))
        try check(abs(decoded[0]-0.21404114)<0.003,"sRGB override transfer")
        let linear=sample(LogConversion.apply(base,input:.init(profile:.linearSRGB,softHighlights:false)))
        try check(abs(linear[0]-0.5)<0.002,"Linear override double conversion")
        let p3=sample(LogConversion.apply(image([1,0,0]),input:.init(profile:.encodedP3,softHighlights:false)))
        try check(p3[0]>1.1 && p3[1]<0,"P3 override gamut")
        let defaults=try JSONDecoder().decode(DeliverySettings.self,from:Data("{\"size\":\"Original\",\"quality\":\"Maximum\"}".utf8))
        try check(defaults.outputSpace == .sRGB,"Legacy delivery space")
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("Finish049-\(UUID())");try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);defer {try? FileManager.default.removeItem(at:folder)}
        let source=folder.appendingPathComponent("source.png")
        try ImageEngine.context().writePNGRepresentation(of:base,to:source,format:.RGBA8,colorSpace:ImageEngine.output)
        var delivery=DeliverySettings();delivery.outputSpace = .displayP3
        let exported=try ImageEngine.export(source:source,recipe:Recipe(),format:.png,delivery:delivery);defer {try? FileManager.default.removeItem(at:exported.url)}
        let provider=CGImageSourceCreateWithURL(exported.url as CFURL,nil)!,properties=CGImageSourceCopyPropertiesAtIndex(provider,0,nil) as! [CFString:Any]
        let profile=properties[kCGImagePropertyProfileName] as? String ?? ""
        try check(profile.lowercased().contains("p3"),"Output profile not embedded: \(profile)")
        for format in [ExportFormat.png,.jpeg] {
            let out=try ImageEngine.export(source:source,recipe:Recipe(),format:format,delivery:delivery);defer {try? FileManager.default.removeItem(at:out.url)}
            let reopened=try ImageEngine.open(out.url,maxDimension:nil)
            try check(zip(sample(reopened.image),sample(base)).allSatisfy {abs($0-$1)<0.02},"P3 tagged preview/export colour mismatch")
        }
        let old=MaskMotion(framing:MaskMotion.signature(Recipe()),start:0,end:2,points:[.init(time:0,x:0,y:0),.init(time:2,x:0.1,y:0,scale:2,rotation:30)])
        var motion=old;motion.setCorrection(time:2,x:0,y:0,tolerance:0.001,scale:1.5,rotation:10)
        try check(abs(motion.pose(at:2).scale-3)<1e-9 && abs(motion.pose(at:2).rotation-40)<1e-9,"Measured/manual pose combination")
        motion.corrections=nil;try check(motion.pose(at:2).scale==2 && motion.pose(at:2).rotation==30,"Clearing manual removed measured pose")
        var recovered=old;recovered.points=[.init(time:0,x:0,y:0),.init(time:0.5,x:0.1,y:0.05,scale:1.2,rotation:10)];recovered.recoveryTime=0.5
        try check(recovered.isValid && recovered.offset(at:1.5).x==0.1 && recovered.pose(at:1.5).scale==1.2,"Partial tracking must hold reliable pose")
        recovered.setCorrection(time:1.5,x:0.2,y:-0.05,tolerance:0.001)
        try check(abs(recovered.offset(at:1.5).x-0.3)<0.00001 && recovered.validCorrections,"Manual tracking recovery")
        try check(try JSONDecoder().decode(MaskMotion.self,from:JSONEncoder().encode(recovered))==recovered,"Recovery metadata persistence")
        try check(try JSONDecoder().decode(MaskMotion.self,from:JSONEncoder().encode(old)).recoveryTime==nil,"Legacy tracking recovery default")
        var bytes=[Float]();for y in 0..<32 {for x in 0..<64 {let r=Float((x+y)%2==0 ? 0.28:0.12),b:Float=0.2,g=(0.2-0.2126*r-0.0722*b)/0.7152;bytes.append(contentsOf:[r,g,b,1])}}
        let data=bytes.withUnsafeBytes {Data($0)},noisy=CIImage(bitmapData:data,bytesPerRow:64*16,size:CGSize(width:64,height:32),format:.RGBAf,colorSpace:ImageEngine.working)
        let clean=PhotoChromaNoise.apply(noisy,amount:1),a=sample(noisy),b=sample(clean),luma:( [Float])->Float={0.2126*$0[0]+0.7152*$0[1]+0.0722*$0[2]}
        try check(abs(luma(a)-luma(b))<0.002 && abs(b[0]-0.2)<abs(a[0]-0.2),"Chroma cleanup lost brightness/detail")
        try check(PhotoChromaNoise.apply(noisy,amount:0) === noisy,"Chroma zero bypass")
        var noiseRecipe=Recipe();noiseRecipe.input=InputConversion(profile:.encodedSRGB,softHighlights:false);noiseRecipe.optics=PhotoOptics(chromaNoise:1)
        let expectedNoise=PhotoChromaNoise.apply(LogConversion.apply(noisy,input:noiseRecipe.input),amount:1)
        try check(zip(sample(ImageEngine.apply(noisy,recipe:noiseRecipe)),sample(expectedNoise)).allSatisfy {abs($0-$1)<0.001},"Chroma cleanup must run after input decoding")
        var shared=Recipe();shared.warmth=0.1;shared.saturation = -0.1;shared.contrast=0.12;shared.look = .bluehour
        let cube=try ColorLUTExport.make(recipe:shared,dimension:33,name:"Studio shared QA"),file=try ColorLUTExport.write(cube)
        defer {try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
        let docs=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        try Data(contentsOf:file).write(to:docs.appendingPathComponent("studio-shared-qa.cube"),options:.atomic)
        let rgb=[10.0/32,16.0/32,22.0/32],ci=CIImage(color:CIColor(red:rgb[0],green:rgb[1],blue:rgb[2],alpha:1,colorSpace:ImageEngine.output)!).cropped(to:CGRect(x:0,y:0,width:2,height:2))
        var expected=[Float](repeating:0,count:4);ImageEngine.context().render(ImageEngine.apply(ci,recipe:shared),toBitmap:&expected,rowBytes:16,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.output)
        try JSONSerialization.data(withJSONObject:["rgb":rgb,"expected":Array(expected.prefix(3))],options:.prettyPrinted).write(to:docs.appendingPathComponent("studio-shared-vectors.json"),options:.atomic)
        var cameraChecked=false
        let camera=docs.appendingPathComponent("camera-shared-qa.cube")
        if FileManager.default.fileExists(atPath:camera.path) {
            let asset=try LUTAsset.read(camera),vectors=try JSONSerialization.jsonObject(with:Data(contentsOf:docs.appendingPathComponent("camera-shared-vectors.json"))) as! [String:[Double]],sample=vectors["rgb"]!
            let input=CIImage(color:CIColor(red:sample[0],green:sample[1],blue:sample[2],alpha:1,colorSpace:ImageEngine.output)!).cropped(to:CGRect(x:0,y:0,width:2,height:2))
            var actual=[Float](repeating:0,count:4);ImageEngine.context().render(asset.apply(input,amount:1),toBitmap:&actual,rowBytes:16,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.output)
            try check(zip(actual,vectors["expected"]!).allSatisfy {abs(Double($0)-$1)<0.015},"Camera-to-Studio colour mismatch");cameraChecked=true
        }
        return ["passed":true,"inputSRGBP3Linear":true,"outputProfile":profile,"legacyDelivery":true,"cameraImportVerified":cameraChecked,"studioShareCreated":true,"lowStoragePreflight":true,"measuredManualPose":true,"chromaBrightnessPreserved":true]
    }
    static func temporal() async throws ->[String:Any] {
        let e=CGRect(x:0,y:0,width:64,height:32),black=CIImage(color:.black).cropped(to:e)
        let context=ImageEngine.context(),gray=CGColorSpace(name:CGColorSpace.linearGray)!
        func frame(_ rect:CGRect,_ time:Double) throws ->TemporalMatte.Frame {let shape=CIImage(color:.white).cropped(to:rect).composited(over:black);return try .init(id:UUID(),time:time,png:context.pngRepresentation(of:shape,format:.L8,colorSpace:gray,options:[:])!,width:64,height:32)}
        let frames=try [frame(CGRect(x:0,y:0,width:32,height:32),0),frame(CGRect(x:32,y:0,width:32,height:32),0.1)]
        let matte=try TemporalMatte(start:0,end:0.2,sourceDuration:0.4,sourceWidth:320,sourceHeight:240,input:InputConversion(),frames:frames)
        try check(matte.frame(at:0.05).id==frames[0].id && matte.frame(at:0.1).id==frames[1].id,"Matte source-time selection")
        let extended=try (0..<900).map {n in TemporalMatte.Frame(id:UUID(),time:Double(n)/60,png:frames[n%2].png,width:64,height:32)}
        let full=try TemporalMatte(start:0,end:15,sourceDuration:15,sourceWidth:320,sourceHeight:240,input:InputConversion(),frames:extended)
        try check(full.frame(at:14.99).id==extended.last!.id,"Extended matte source-time lookup")
        let roundtrip=try JSONDecoder().decode(TemporalMatte.self,from:JSONEncoder().encode(full));try check(roundtrip==full && roundtrip.frames.count==900,"Extended matte persistence")
        do {_ = try TemporalMatte(start:0,end:15.1,sourceDuration:15.1,sourceWidth:320,sourceHeight:240,input:InputConversion(),frames:extended+[.init(id:UUID(),time:15,png:frames[0].png,width:64,height:32)]);throw PointSampling.failure("Unexpected901")} catch let e as NSError {try check(e.domain != "PointSample","Matte frame bound")}
        let automatic=AutomaticMask(id:frames[0].id,png:frames[0].png,width:64,height:32,framing:MaskMotion.signature(Recipe()),videoStart:0,temporal:matte)
        var r=Recipe(),layer=LocalMask(kind:.subject);layer.automatic=automatic;layer.cutout=true;r.masks=[layer];r.background=PhotoBackground(mode:.solid,red:0,green:0,blue:1);r.video.end=0.2
        let source=image([1,0,0],size:CGSize(width:320,height:240))
        func render(_ time:Double,_ recipe:Recipe)->CIImage {MaskMotion.$frame.withValue(.init(time:time,framing:MaskMotion.signature(recipe))){ImageEngine.apply(source,recipe:recipe)}}
        let first=sample(render(0,r),x:60,y:120),last=sample(render(0.1,r),x:60,y:120)
        try check(first[0]>0.9 && first[2]<0.01 && last[2]>0.9 && last[0]<0.01,"Time-varying cutout/background")
        var crop=r;crop.crop = .square;crop.video.start=0.1
        try check(automatic.matches(crop),"Saved full-frame matte rejected compatible crop/trim")
        let cropped=render(0.1,crop);try check(cropped.extent.width==cropped.extent.height && sample(cropped,x:20,y:120)[2]>0.9,"Matte source aspect/crop projection")
        r.masks[0].label="People video matte";r.masks[0].automatic?.selectionMode = .people
        let saved=try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(r));try check(saved==r && saved.masks[0].automatic?.temporal==matte,"Matte persistence")
        var invalid=r;invalid.video.end=0.3;try check(!automatic.matches(invalid),"Matte trim extension accepted")
        let movie=try await VideoFixtures.make(profile:.standard,frames:12,audioTracks:1,width:320,height:240,linear:[1,0,0]);defer {try? FileManager.default.removeItem(at:movie.deletingLastPathComponent())}
        VerificationProgress.record("Finish049 temporal movie describe/export")
        let descriptor=try await VideoEngine.describe(movie),out=try await VideoEngine.export(source:movie,descriptor:descriptor,recipe:r,progress:{_ in});defer {try? FileManager.default.removeItem(at:out.url)}
        VerificationProgress.record("Finish049 temporal output decode")
        let described=try await VideoEngine.describe(out.url),poster=try await VideoEngine.poster(out.url,descriptor:described,maxDimension:320,time:0.12)
        try check(sample(poster.image,x:60,y:120)[2]>0.8,"Encoded video replacement mask")
        VerificationProgress.record("Finish049 temporal backup")
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("TemporalArchive-\(UUID())"),vault=ProjectVault(root:folder);defer {try? FileManager.default.removeItem(at:folder)}
        var project=try await vault.importPhoto(movie);project.recipe=r;project=try await vault.save(project)
        let archive=try await vault.writeArchive([project.id]);defer {try? FileManager.default.removeItem(at:archive.deletingLastPathComponent())}
        let restored=try await vault.restoreArchive(archive);try check(restored.first?.recipe==r,"Matte archive restore")
        return ["passed":true,"sourceTimeAndCrop":true,"encodedVideoReplacement":true,"persistenceBackup":true,"noPlaybackInference":true,"extended900FrameRoundtrip":true]
    }
    static func personClip(_ source:URL,frames:Int=12) async throws ->URL {
        let photo=try ImageEngine.open(source,maxDimension:768),e=CGRect(x:0,y:0,width:320,height:480)
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("PersonClip-\(UUID())");try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let url=folder.appendingPathComponent("person.mov"),writer=try AVAssetWriter(outputURL:url,fileType:.mov),input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:320,AVVideoHeightKey:480])
        let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:320,kCVPixelBufferHeightKey as String:480,kCVPixelBufferIOSurfacePropertiesKey as String:[:]])
        writer.add(input);guard writer.startWriting() else {throw StudioError.render};writer.startSession(atSourceTime:.zero)
        let factor=max(e.width/photo.image.extent.width,e.height/photo.image.extent.height),picture=photo.image.transformed(by:.init(scaleX:factor,y:factor)),context=ImageEngine.context()
        for n in 0..<frames {
            while !input.isReadyForMoreMediaData {try await Task.sleep(for:.milliseconds(2))}
            var buffer:CVPixelBuffer?;guard let pool=adaptor.pixelBufferPool,CVPixelBufferPoolCreatePixelBuffer(nil,pool,&buffer)==kCVReturnSuccess,let buffer else {throw StudioError.render}
            let frame=picture.transformed(by:.init(translationX:sin(Double(n)*0.07)*8,y:0)).cropped(to:e)
            context.render(frame,to:buffer,bounds:e,colorSpace:ImageEngine.output)
            guard adaptor.append(buffer,withPresentationTime:CMTime(value:Int64(n),timescale:30)) else {throw StudioError.render}
        }
        input.markAsFinished();await writer.finishWriting();guard writer.status == .completed else {throw StudioError.render};return url
    }
    static func models(_ portrait:URL) async throws ->[String:Any] {
        VerificationProgress.record("Finish049 face selection")
        let trackingOnly=ProcessInfo.processInfo.arguments.contains("--tracking-models-only")
        var peopleFrames=0,matteBytes=0
        if !trackingOnly {
        let photo=try ImageEngine.open(portrait,maxDimension:1024),context=ImageEngine.context()
        let cg=context.createCGImage(photo.image,from:photo.image.extent,format:.RGBA8,colorSpace:ImageEngine.output)!
        let faces=try FaceSelection.make(cg,skin:false),skin=try FaceSelection.make(cg,skin:true)
        try check(AutomaticSelectionEngine.hasCoverage(faces) && AutomaticSelectionEngine.hasCoverage(skin),"Face/skin selection coverage")
        let faceRequest=VNDetectFaceRectanglesRequest();try VNImageRequestHandler(cgImage:cg,orientation:.up).perform([faceRequest])
        if let box=faceRequest.results?.first?.boundingBox {try check(sample(faces,x:box.midX*faces.extent.width,y:box.midY*faces.extent.height)[0]>0.5,"Face matte orientation")}
        let count=ProcessInfo.processInfo.arguments.contains("--extended-matte-check") ? 450:12
        let movie=try await personClip(portrait,frames:count);defer {try? FileManager.default.removeItem(at:movie.deletingLastPathComponent())}
        VerificationProgress.record("Finish049 person matting")
        let docs=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0],debugMovie=docs.appendingPathComponent("person-fixture-049.mov")
        try? FileManager.default.removeItem(at:debugMovie);try FileManager.default.copyItem(at:movie,to:debugMovie)
        let descriptor:VideoDescriptor
        do {descriptor=try await VideoEngine.describe(movie)} catch {throw PointSampling.failure("Person fixture description: "+error.localizedDescription)}
        VerificationProgress.record("Finish049 person matte reader")
        let stored=try await PeopleVideoMatte.analyze(url:movie,descriptor:descriptor,recipe:Recipe(),progress:{_ in})
        try check(stored.temporal?.frames.count==count,"Every person frame was processed")
        let cancelled=Task.detached {try await PeopleVideoMatte.analyze(url:movie,descriptor:descriptor,recipe:Recipe(),progress:{_ in})};cancelled.cancel()
        do {_ = try await cancelled.value;throw PointSampling.failure("Unexpected completed cancellation")} catch is CancellationError {} catch {throw error}
        peopleFrames=stored.temporal!.frames.count;matteBytes=stored.temporal!.frames.reduce(0){$0+$1.png.count}
        }
        VerificationProgress.record("Finish049 rectangle tracking")
        let tracking=try await TrackingVerification.fixture(pose:true);defer {try? FileManager.default.removeItem(at:tracking.deletingLastPathComponent())}
        let trackDescriptor=try await VideoEngine.describe(tracking),seed=TrackingSeed(x:0.3,y:0.5,width:0.2,height:0.25)
        let motion=try await MaskTracker.analyze(url:tracking,descriptor:trackDescriptor,recipe:Recipe(),seed:seed,quality:.detailed,geometry:.rectangle,progress:{_ in})
        let sized=try await MaskTracker.analyze(url:tracking,descriptor:trackDescriptor,recipe:Recipe(),seed:seed,quality:.detailed,geometry:.size,progress:{_ in})
        let end=motion.pose(at:motion.end),expectedScale=1+0.25*(motion.points.last!.time/(59.0/30)),expectedAngle = -0.2*180/Double.pi*(motion.points.last!.time/(59.0/30))
        try check(abs(end.scale-expectedScale)<0.2 && abs(end.rotation-expectedAngle)<8,"Rectangle pose inaccurate: \(end) expected \(expectedScale),\(expectedAngle)")
        try check(abs(sized.pose(at:sized.end).scale-expectedScale)<0.2,"Object size tracking inaccurate: \(sized.pose(at:sized.end).scale)")
        let lostMovie=try await TrackingVerification.fixture(disappear:true);defer {try? FileManager.default.removeItem(at:lostMovie.deletingLastPathComponent())}
        let lostDescriptor=try await VideoEngine.describe(lostMovie)
        let partial=try await MaskTracker.analyze(url:lostMovie,descriptor:lostDescriptor,recipe:Recipe(),seed:seed,recoverUsablePath:true,progress:{_ in})
        try check(partial.recoveryTime != nil && partial.points.count>=2 && partial.points.count<motion.points.count && partial.isValid,"Lost target did not produce bounded reviewable path")
        try check(partial.offset(at:partial.end).x==partial.points.last!.x,"Lost target must hold last reliable position")
        return ["lostTargetRecovery":true,"cancellation":!trackingOnly,"objectScale":sized.pose(at:sized.end).scale,"passed":true,"faceAndFacialSkin":!trackingOnly,"peopleFrames":peopleFrames,"matteBytes":matteBytes,"rectangleScale":end.scale,"rectangleRotation":end.rotation,"scope":"Public NASA portrait animated as a test clip, plus a synthetic rotating rectangle; not real moving-hair or occlusion coverage"]
    }
    @MainActor static func writeReport() async {
        let docs=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0],url=docs.appendingPathComponent("finish-049-verification.json")
        try? FileManager.default.removeItem(at:url)
        do {
            let report=try await Task.detached(priority:.utility) {() async throws ->[String:Any] in
                var r:[String:Any]=[:]
                VerificationProgress.record("Finish049 math")
                do {r["math"]=try math()} catch {throw PointSampling.failure("Finish049 math: "+error.localizedDescription)}
                VerificationProgress.record("Finish049 temporal export/backup")
                do {r["temporal"]=try await temporal()} catch {throw PointSampling.failure("Finish049 temporal: "+error.localizedDescription)}
                if ProcessInfo.processInfo.arguments.contains("--verify-finish-models") {VerificationProgress.record("Finish049 Vision models");do {r["models"]=try await models(docs.appendingPathComponent("StudioPersonQA.jpg"))} catch {throw PointSampling.failure("Finish049 models: "+error.localizedDescription)}}
                r["passed"]=true;r["version"]=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown";r["thermal"]=ProcessInfo.processInfo.thermalState.rawValue;return r
            }.value
            try JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:url,options:.atomic)
        } catch {try? JSONSerialization.data(withJSONObject:["passed":false,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","error":error.localizedDescription],options:.prettyPrinted).write(to:url,options:.atomic)}
    }
}
#endif
