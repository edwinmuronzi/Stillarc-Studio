#if DEBUG
import AVFoundation
import CoreImage
import Foundation

enum TrackingVerification {
    static func check(_ v:Bool,_ text:String) throws { if !v { throw NSError(domain:"TrackingVerification",code:1,userInfo:[NSLocalizedDescriptionKey:text]) } }
    static func math() throws -> [String:Any] {
        let recipe = Recipe(),signature = MaskMotion.signature(recipe)
        let motion = MaskMotion(framing:signature,start:0,end:2,points:[.init(time:0,x:0,y:0),.init(time:1,x:0.2,y:0.1),.init(time:2,x:0.3,y:0)])
        try check(motion.isValid && abs(motion.offset(at:0.5).x-0.1)<0.0001 && abs(motion.offset(at:0.5).y-0.05)<0.0001,"Motion interpolation")
        var corrected=motion
        corrected.setCorrection(time:1,x:0.1,y:-0.1,tolerance:0.001)
        try check(corrected.corrections?.count==2 && abs(corrected.offset(at:0.5).x-0.15)<0.000001 && abs(corrected.offset(at:1).y)<0.000001,"Correction interpolation/anchor/axes")
        try check(corrected.offset(at:2).x==0.4 && corrected.baseOffset(at:2).x==0.3,"Held correction/unaltered base")
        let old=try JSONEncoder().encode(motion),oldObject=try JSONSerialization.jsonObject(with:old) as! [String:Any]
        try check(oldObject["corrections"]==nil && (try JSONDecoder().decode(MaskMotion.self,from:old)).corrections==nil,"Legacy correction default")
        let correctedData=try JSONEncoder().encode(corrected)
        try check(try JSONDecoder().decode(MaskMotion.self,from:correctedData)==corrected,"Correction persistence")
        var malformed=corrected;malformed.corrections=[.init(time:1,x:20,y:0)]
        try check((try JSONDecoder().decode(MaskMotion.self,from:JSONEncoder().encode(malformed))).corrections==nil,"Invalid corrections sanitized")
        var capped=motion
        for i in 0..<40 {capped.setCorrection(time:Double(i)/20,x:0.1,y:0,tolerance:0)}
        try check(capped.corrections?.count==32 && capped.validCorrections,"Correction bound")
        corrected.corrections=nil;try check(corrected==motion,"Clear corrections preserves analysis")
        let extent = CGRect(x:0,y:0,width:100,height:100),context = ImageEngine.context()
        var radial = LocalMask(kind:.radial);radial.centerX = 0.3;radial.width = 0.1;radial.height = 0.1;radial.motion = motion;radial.exposure = 1
        func sample(_ image:CIImage,_ x:Int,_ y:Int) -> Float { var p = [Float](repeating:0,count:4);context.render(image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:x,y:y,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p[0] }
        let moved = MaskMotion.$frame.withValue(.init(time:1,framing:signature)) { MaskEngine.weight(radial,extent:extent) }
        try check(sample(moved,50,40)>0.99 && sample(moved,30,50)<0.001,"Tracking axes or mask translation")
        var inverted = radial;inverted.inverted = true
        let inv = MaskMotion.$frame.withValue(.init(time:1,framing:signature)) { MaskEngine.weight(inverted,extent:extent) }
        try check(sample(inv,1,1)>0.99 && sample(inv,50,40)<0.001,"Translated inversion edge coverage")
        var saved = recipe;saved.masks = [radial]
        try check(try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(saved)) == saved,"Tracking persistence")
        try check(saved.colorPreset.masks.isEmpty,"Tracking leaked into preset")
        try MaskMotion.validateExport(saved,duration:2)
        var crop = saved;crop.crop = .square
        do { try MaskMotion.validateExport(crop,duration:2);throw StudioError.render } catch let e as NSError { try check(e.domain == "MaskTracking","Crop invalidation") }
        do { try MaskMotion.validateExport(saved,duration:3);throw StudioError.render } catch let e as NSError { try check(e.domain == "MaskTracking","Trim extension invalidation") }
        let legacy = try JSONDecoder().decode(LocalMask.self,from:JSONEncoder().encode(LocalMask(kind:.radial)))
        try check(legacy.motion == nil,"Legacy tracking default")
        var bad = motion;bad.points.reverse()
        let decoded = try JSONDecoder().decode(MaskMotion.self,from:JSONEncoder().encode(bad))
        try check(decoded.points.isEmpty,"Invalid tracking data not sanitized")
        return ["passed":true,"interpolation":true,"timestampAxes":true,"inversionEdges":true,"persistence":true,"cropTrimInvalidation":true,"legacyDefaults":true,"invalidData":true,"correctionInterpolationAnchorHoldingBounds":true,"correctionPersistenceLegacyAndReset":true]
    }
    static func writeCorrectionReport() async {
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("tracking-correction-verification.json")
        try? FileManager.default.removeItem(at:url)
        var result=await Task.detached(priority:.utility) {()->[String:Any] in do {return ["passed":true,"math":try math(),"video":try await video()]} catch {return ["passed":false,"error":error.localizedDescription]}}.value
        result["version"]=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String
        result["thermal"]=ProcessInfo.processInfo.thermalState.rawValue
        if let data=try? JSONSerialization.data(withJSONObject:result,options:.prettyPrinted){try? data.write(to:url,options:.atomic)}
    }
    static func fixture(rotated:Bool = false,frames:Int = 60,pose:Bool=false,disappear:Bool=false) async throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TrackingFixture-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let url = root.appendingPathComponent("moving.mov"),writer = try AVAssetWriter(outputURL:root.appendingPathComponent("moving.mov"),fileType:.mov)
        let input = AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:640,AVVideoHeightKey:360])
        if rotated { input.transform = CGAffineTransform(a:0,b:1,c:-1,d:0,tx:360,ty:0) }
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:640,kCVPixelBufferHeightKey as String:360,kCVPixelBufferIOSurfacePropertiesKey as String:[:]])
        writer.add(input);guard writer.startWriting() else { throw StudioError.render };writer.startSession(atSourceTime:.zero)
        let context = ImageEngine.context(),extent = CGRect(x:0,y:0,width:640,height:360)
        let checker = CIFilter(name:"CICheckerboardGenerator",parameters:["inputCenter":CIVector(x:0,y:0),"inputColor0":CIColor(red:0.8,green:0.15,blue:0.08),"inputColor1":CIColor.white,"inputWidth":9,"inputSharpness":1])!.outputImage!
        for n in 0..<frames {
            try Task.checkCancellation()
            while !input.isReadyForMoreMediaData { try await Task.sleep(for:.milliseconds(2)) }
            try autoreleasepool {
                var buffer:CVPixelBuffer?
                guard let pool = adaptor.pixelBufferPool,CVPixelBufferPoolCreatePixelBuffer(nil,pool,&buffer) == kCVReturnSuccess,let buffer else { throw StudioError.render }
                let x = 192+128*Double(n)/Double(max(1,frames-1)),rect = CGRect(x:x-48,y:144,width:96,height:72)
                let background = CIImage(color:CIColor(red:0.08,green:0.09,blue:0.1)).cropped(to:extent)
                var target = checker.transformed(by:.init(translationX:x-48,y:144)).cropped(to:rect)
                if pose {
                    let border=CIImage(color:.white).cropped(to:rect),inner=target.cropped(to:rect.insetBy(dx:5,dy:5))
                    let t=Double(n)/Double(max(1,frames-1)),s=1+0.25*t
                    target=inner.composited(over:border).transformed(by:.init(translationX:-x,y:-180)).transformed(by:.init(scaleX:s,y:s)).transformed(by:.init(rotationAngle:0.2*t)).transformed(by:.init(translationX:x,y:180))
                }
                if disappear && n>=frames/2 {target=background}
                context.render(target.composited(over:background),to:buffer,bounds:extent,colorSpace:ImageEngine.output)
                guard adaptor.append(buffer,withPresentationTime:CMTime(value:Int64(n),timescale:30)) else { throw StudioError.render }
            }
        }
        input.markAsFinished();await writer.finishWriting();guard writer.status == .completed else { throw StudioError.render };return url
    }
    static func video() async throws -> [String:Any] {
        var errors = [Double](),counts = [Int]()
        for rotated in (ProcessInfo.processInfo.arguments.contains("--portrait-first") ? [true,false] : [false,true]) {
            VerificationProgress.record("Tracking fixture \(rotated ? "portrait" : "landscape")")
            let url = try await fixture(rotated:rotated)
            defer { try? FileManager.default.removeItem(at:url.deletingLastPathComponent()) }
            let descriptor = try await VideoEngine.describe(url),recipe = Recipe()
            let seed = rotated ? TrackingSeed(x:0.5,y:0.7,width:0.25,height:0.2) : TrackingSeed(x:0.3,y:0.5,width:0.2,height:0.25)
            VerificationProgress.record("Tracking analysis \(rotated ? "portrait" : "landscape")")
            let motion = try await MaskTracker.analyze(url:url,descriptor:descriptor,recipe:recipe,seed:seed,progress:{ _ in })
            let last = motion.points.last!,expected = 0.2*last.time/(59.0/30)
            let error = rotated ? abs(last.y+expected)+abs(last.x) : abs(last.x-expected)+abs(last.y)
            try check(error<0.05,"Moving target tracking/orientation error: \(error), \(last)")
            errors.append(error);counts.append(motion.points.count)
            var trackedRecipe = Recipe();var mask = LocalMask(kind:.radial);mask.centerX = seed.x;mask.centerY = seed.y;mask.width = 0.14;mask.height = 0.14;mask.feather = 0.1;mask.exposure = 1;mask.motion = motion;trackedRecipe.masks = [mask]
            // Deliberately wrong base path repaired by source-time points. Encoded pixels must follow the actual target again.
            let measured=motion
            var drifted=motion;drifted.points=motion.points.map {.init(time:$0.time,x:$0.x+0.12,y:$0.y-0.08)}
            drifted.setCorrection(time:drifted.start,x:-0.12,y:0.08,tolerance:0.001)
            drifted.setCorrection(time:drifted.end,x:-0.12,y:0.08,tolerance:0.001)
            trackedRecipe.masks[0].motion=drifted
            try check(abs(drifted.offset(at:1).x-measured.offset(at:1).x)<0.000001,"Corrected measured path")
            VerificationProgress.record("Tracking export \(rotated ? "portrait" : "landscape")")
            let output = try await VideoEngine.export(source:url,descriptor:descriptor,recipe:trackedRecipe,tenBit:false,progress:{ _ in })
            defer { try? FileManager.default.removeItem(at:output.url) }
            let info = try await VideoEngine.describe(output.url)
            let exportedAsset = AVURLAsset(url:output.url)
            let reader = try AVAssetReader(asset:exportedAsset)
            let track = try await exportedAsset.loadTracks(withMediaType:.video).first!
            let samples = AVAssetReaderTrackOutput(track:track,outputSettings:nil);guard reader.canAdd(samples) else { throw StudioError.render };reader.add(samples);reader.startReading();var frameCount = 0
            while let sample = samples.copyNextSampleBuffer() { if CMSampleBufferGetTotalSampleSize(sample)>0 { frameCount += 1 } }
            try check(reader.status == .completed && frameCount == 60,"Tracked export frame count: \(frameCount), reader \(reader.status.rawValue)")
            try check(info.width == descriptor.width && info.height == descriptor.height && abs(info.duration-descriptor.duration)<0.04,"Tracked export size/timing")
            func frame(_ url:URL) async throws -> CIImage {
                let generator = AVAssetImageGenerator(asset:AVURLAsset(url:url));generator.appliesPreferredTrackTransform = true;generator.requestedTimeToleranceBefore = .zero;generator.requestedTimeToleranceAfter = .zero
                return CIImage(cgImage:try await generator.image(at:CMTime(seconds:1.9,preferredTimescale:600)).image)
            }
            let before = try await frame(url),after = try await frame(output.url),context = ImageEngine.context()
            func patch(_ image:CIImage,_ x:Double,_ y:Double) -> Float {
                let rect = CGRect(x:image.extent.width*x,y:image.extent.height*y,width:2,height:2)
                let average = image.applyingFilter("CIAreaAverage",parameters:["inputExtent":CIVector(cgRect:rect)])
                var p = [Float](repeating:0,count:4);context.render(average,toBitmap:&p,rowBytes:16,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p[0]
            }
            let x = rotated ? 0.5 : 0.6,y = rotated ? 0.4 : 0.5,oldX = rotated ? 0.5 : 0.3,oldY = rotated ? 0.3 : 0.5
            try check(abs(patch(after,x,y)-patch(before,x,y)*2)<0.025 && abs(patch(after,oldX,oldY)-patch(before,oldX,oldY))<0.025,"Encoded tracking did not move the local adjustment")

            let task = Task { try await MaskTracker.analyze(url:url,descriptor:descriptor,recipe:recipe,seed:seed,progress:{ _ in }) };task.cancel()
            do { _ = try await task.value;throw StudioError.render } catch is CancellationError {}
        }
        return ["passed":true,"movingTargetErrors":errors,"pointCounts":counts,"portraitLandscape":true,"cancellation":true,"encodedTracking":true,"encodedCorrections":true,"exportFramesPerClip":60]
    }
}
#endif
