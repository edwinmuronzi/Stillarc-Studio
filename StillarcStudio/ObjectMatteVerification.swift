#if DEBUG
import AVFoundation
import CoreImage
import Vision

enum ObjectMatteVerification {
    static func check(_ value:Bool,_ text:String) throws {try Finish049Verification.check(value,text)}
    static func map(_ items:[(UInt8,CGRect)])->ObjectVideoMatteTracker.LabelMap {
        var buffer:CVPixelBuffer?;CVPixelBufferCreate(nil,64,64,kCVPixelFormatType_OneComponent8,[kCVPixelBufferIOSurfacePropertiesKey as String:[:]] as CFDictionary,&buffer)
        let b=buffer!;CVPixelBufferLockBaseAddress(b,[]);let data=CVPixelBufferGetBaseAddress(b)!.assumingMemoryBound(to:UInt8.self),stride=CVPixelBufferGetBytesPerRow(b)
        for y in 0..<64 {for x in 0..<64 {data[y*stride+x]=0}}
        for (id,r) in items {for y in 0..<64 {for x in 0..<64 where r.contains(CGPoint(x:(Double(x)+0.5)/64,y:(Double(y)+0.5)/64)) {data[y*stride+x]=id}}}
        CVPixelBufferUnlockBaseAddress(b,[]);return try! .init(buffer:b)
    }
    static func math() throws ->[String:Any] {
        let box=CGRect(x:0.125,y:0.25,width:0.25,height:0.25),moved=box.offsetBy(dx:0.125,dy:0.0625)
        let old=map([(1,box)]),current=map([(7,moved),(1,CGRect(x:0.75,y:0.7,width:0.125,height:0.125))])
        try check(try ObjectVideoMatteTracker.select(current:current,previous:old,id:1,predicted:moved)==7,"Object identity used unstable frame label")
        try check(old.instance(at:CGPoint(x:0.2,y:0.3))==1 && old.instance(at:CGPoint(x:0.2,y:0.8))==nil,"Object tap vertical axis")
        try check(ObjectVideoMatteTracker.visionRect(ObjectVideoMatteTracker.visionRect(box))==box,"Vision/UI rectangle conversion")
        let split=map([(3,CGRect(x:box.minX,y:box.minY,width:box.width/2,height:box.height)),(4,CGRect(x:box.midX,y:box.minY,width:box.width/2,height:box.height))])
        for candidate in [split,map([])] {
            var rejected=false;do {_ = try ObjectVideoMatteTracker.select(current:candidate,previous:old,id:1,predicted:box)} catch {rejected=true}
            try check(rejected,"Ambiguous/missing object must not switch target")
        }
        return ["passed":true,"renumberedInstances":true,"ambiguousAndMissingRejected":true,"tapAndVisionCoordinates":true]
    }
    static func fixture(_ source:URL,frames:Int=24) async throws ->URL {
        let photo=try ImageEngine.open(source,maxDimension:1024),extent=CGRect(x:0,y:0,width:640,height:480)
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("ObjectClip-\(UUID())");try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let url=root.appendingPathComponent("object.mov"),writer=try AVAssetWriter(outputURL:url,fileType:.mov)
        let input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:640,AVVideoHeightKey:480])
        let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:640,kCVPixelBufferHeightKey as String:480,kCVPixelBufferIOSurfacePropertiesKey as String:[:]])
        writer.add(input);guard writer.startWriting() else {throw StudioError.render};writer.startSession(atSourceTime:.zero)
        let e=photo.image.extent,factor=min(extent.width/e.width,extent.height/e.height)*0.85
        let base=photo.image.transformed(by:.init(translationX:-e.midX,y:-e.midY)).transformed(by:.init(scaleX:factor,y:factor)),context=ImageEngine.context()
        for n in 0..<frames {
            try Task.checkCancellation();while !input.isReadyForMoreMediaData {try await Task.sleep(for:.milliseconds(2))}
            var buffer:CVPixelBuffer?;guard let pool=adaptor.pixelBufferPool,CVPixelBufferPoolCreatePixelBuffer(nil,pool,&buffer)==kCVReturnSuccess,let buffer else {throw StudioError.render}
            let t=Double(n)/Double(max(1,frames-1)),s=1+0.08*t
            let moving=base.transformed(by:.init(scaleX:s,y:s)).transformed(by:.init(rotationAngle:0.04*t)).transformed(by:.init(translationX:320+12*t,y:240))
            context.render(moving.composited(over:CIImage(color:.black)).cropped(to:extent),to:buffer,bounds:extent,colorSpace:ImageEngine.output)
            guard adaptor.append(buffer,withPresentationTime:CMTime(value:Int64(n),timescale:30)) else {throw StudioError.render}
        }
        input.markAsFinished();await writer.finishWriting();guard writer.status == .completed else {throw StudioError.render};return url
    }
    static func native(_ source:URL) async throws ->[String:Any] {
        let clip=try await fixture(source);defer {try? FileManager.default.removeItem(at:clip.deletingLastPathComponent())}
        let descriptor=try await VideoEngine.describe(clip),point=CGPoint(x:0.55,y:0.5)
        let matte=try await PeopleVideoMatte.analyze(url:clip,descriptor:descriptor,recipe:Recipe(),objectPoint:point,progress:{_ in})
        try check(matte.selectionMode == .picked && matte.temporal?.frames.count==24,"Every object frame must be segmented")
        let temporal=matte.temporal!,first=temporal.frames[0],last=temporal.frames.last!
        try check(first.png != last.png,"Object silhouette not refreshed")
        var r=Recipe(),layer=LocalMask(kind:.subject);layer.automatic=matte;layer.label="Object video matte";r.masks=[layer];r.setCutout(layer.id,enabled:true);r.background=PhotoBackground(mode:.solid,red:0,green:1,blue:0)
        let roundtrip=try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(r));try check(roundtrip==r,"Object matte recipe persistence")
        let out=try await VideoEngine.export(source:clip,descriptor:descriptor,recipe:r,progress:{_ in});defer {try? FileManager.default.removeItem(at:out.url)}
        let exported=try await VideoEngine.describe(out.url),poster=try await VideoEngine.poster(out.url,descriptor:exported,maxDimension:640,time:0.4)
        let background=Finish049Verification.sample(poster.image,x:10,y:470)
        try check(background[1]>0.8 && background[0]<0.1,"Object background replacement export")
        try check(exported.width==640 && exported.height==480 && abs(exported.duration-descriptor.duration)<0.04,"Object export dimensions/timing")
        var invalid=r;invalid.input.profile = .appleLog;try check(!matte.matches(invalid),"Changed object input accepted stale matte")
        var cropped=r;cropped.crop = .square;cropped.video.start=0.1;try check(matte.matches(cropped),"Object matte crop/shorter trim reuse")
        let cancelled=Task.detached {try await PeopleVideoMatte.analyze(url:clip,descriptor:descriptor,recipe:Recipe(),objectPoint:point,progress:{_ in})};cancelled.cancel()
        do {_ = try await cancelled.value;throw PointSampling.failure("Object cancellation ignored")} catch is CancellationError {}
        return ["passed":true,"frames":temporal.frames.count,"savedBytes":temporal.frames.reduce(0){$0+$1.png.count},"freshSilhouettes":true,"persistence":true,"encodedBackgroundReplacement":true,"cropAndTrimReuse":true,"cancellation":true,"thermal":ProcessInfo.processInfo.thermalState.rawValue,"scope":"Animated Smithsonian Hasselblad camera photograph, not real moving or deforming-object footage"]
    }
    @MainActor static func writeReport() async {
        let docs=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0],report=docs.appendingPathComponent("object-matte-verification.json")
        try? FileManager.default.removeItem(at:report)
        do {
            let r=try await Task.detached(priority:.utility) {() async throws ->[String:Any] in
                var results:[String:Any]=["math":try math(),"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown"]
                if ProcessInfo.processInfo.arguments.contains("--verify-object-model") {results["native"]=try await native(docs.appendingPathComponent("StudioObjectQA.jpg"))}
                results["passed"]=true;return results
            }.value
            try JSONSerialization.data(withJSONObject:r,options:.prettyPrinted).write(to:report,options:.atomic)
        } catch {try? JSONSerialization.data(withJSONObject:["passed":false,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","error":error.localizedDescription],options:.prettyPrinted).write(to:report,options:.atomic)}
    }
}
#endif
