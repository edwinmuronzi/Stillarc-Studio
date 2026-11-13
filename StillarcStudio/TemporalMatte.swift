import AVFoundation
import CoreImage
import CryptoKit
import Vision

/// Immutable, bounded source-time mattes. No model execution during playback/export.
final class TemporalMatte:Codable,Equatable,@unchecked Sendable {
    struct Frame:Codable,Sendable {let id:UUID;let time:Double;let png:Data;let width:Int;let height:Int}
    let start:Double,end:Double,sourceDuration:Double
    let sourceWidth:Int,sourceHeight:Int
    let input:InputConversion
    let frames:[Frame]
    let fingerprint:String
    private enum CodingKeys:String,CodingKey {case start,end,sourceDuration,sourceWidth,sourceHeight,input,frames}
    static func ==(a:TemporalMatte,b:TemporalMatte)->Bool {a === b || a.fingerprint==b.fingerprint}
    init(start:Double,end:Double,sourceDuration:Double,sourceWidth:Int,sourceHeight:Int,input:InputConversion,frames:[Frame]) throws {
        guard (2...4096).contains(sourceWidth),(2...4096).contains(sourceHeight),start.isFinite,end.isFinite,sourceDuration.isFinite,start>=0,end>start,end<=sourceDuration+0.001,sourceDuration<=604800,!frames.isEmpty,frames.count<=360,Set(frames.map(\.id)).count==frames.count else {throw AutomaticSelectionEngine.error("This saved video matte is invalid or too large.")}
        var bytes=0,hash=SHA256()
        for f in frames {
            guard f.time.isFinite,f.time>=start-0.002,f.time<end+0.002,f.width>0,f.height>0,f.width<=1536,f.height<=1536,!f.png.isEmpty,f.png.count<=4_194_304 else {throw AutomaticSelectionEngine.error("A saved matte frame has invalid dimensions, timing or image data. Rebuild the video matte.")}
            bytes+=f.png.count;guard bytes<=16_777_216 else {throw AutomaticSelectionEngine.error("The matte exceeds the 16 MB processing budget. Shorten the kept clip and try again.")}
            hash.update(data:f.png);hash.update(data:Data("\(f.time):\(f.width):\(f.height)".utf8))
        }
        guard zip(frames,frames.dropFirst()).allSatisfy({$0.time<$1.time}) else {throw AutomaticSelectionEngine.error("Saved video matte frames are not in source-time order. Rebuild the video matte.")}
        let encoder=JSONEncoder();encoder.outputFormatting = .sortedKeys;hash.update(data:try encoder.encode(input));hash.update(data:Data("\(start):\(end):\(sourceDuration):\(sourceWidth):\(sourceHeight)".utf8))
        self.sourceWidth=sourceWidth;self.sourceHeight=sourceHeight;self.start=start;self.end=end;self.sourceDuration=sourceDuration;self.input=input;self.frames=frames
        fingerprint=hash.finalize().map {String(format:"%02x",$0)}.joined()
    }
    convenience init(from decoder:Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        try self.init(start:c.decode(Double.self,forKey:.start),end:c.decode(Double.self,forKey:.end),sourceDuration:c.decode(Double.self,forKey:.sourceDuration),sourceWidth:c.decode(Int.self,forKey:.sourceWidth),sourceHeight:c.decode(Int.self,forKey:.sourceHeight),input:c.decode(InputConversion.self,forKey:.input),frames:c.decode([Frame].self,forKey:.frames))
    }
    func matches(_ recipe:Recipe)->Bool {
        let range=recipe.video.range(duration:sourceDuration)
        return input==recipe.input && range.lowerBound>=start-0.002 && range.upperBound<=end+0.002
    }
    func frame(at time:Double)->Frame {
        guard time.isFinite,time>frames[0].time else {return frames[0]}
        var low=0,high=frames.count
        while low+1<high {let mid=(low+high)/2;if frames[mid].time<=time+0.00001 {low=mid} else {high=mid}}
        return frames[low]
    }
}
enum TemporalMatteProjection {
    private final class Cache:@unchecked Sendable {let lock=NSLock();var entries:[String:Recipe]=[:]}
    private static let cache=Cache()
    static func recipe(_ signature:String)->Recipe? {
        cache.lock.lock();let old=cache.entries[signature];cache.lock.unlock();if let old {return old}
        guard let r=MaskFramingRepair.snapshot(signature) else {return nil}
        cache.lock.lock();if cache.entries.count>=16 {cache.entries.removeAll()};cache.entries[signature]=r;cache.lock.unlock();return r
    }
}
enum PeopleVideoMatte {
    static func analyze(url:URL,descriptor:VideoDescriptor,recipe:Recipe,progress:@escaping @Sendable(Double) async->Void) async throws ->AutomaticMask {
        try Task.checkCancellation()
        let range=recipe.video.range(duration:descriptor.duration)
        guard range.upperBound-range.lowerBound<=12.001,(range.upperBound-range.lowerBound)*descriptor.frameRate<=360.1 else {throw AutomaticSelectionEngine.error("Trim the kept clip to at most 12 seconds and 360 frames before making a People video matte.")}
        #if DEBUG
        VerificationProgress.record("People matte open reader")
        #endif
        let asset=AVURLAsset(url:url)
        guard let track=try await asset.loadTracks(withMediaType:.video).first else {throw StudioError.unreadable}
        let reader=try AVAssetReader(asset:asset),output=AVAssetReaderTrackOutput(track:track,outputSettings:MaskTracker.settings(descriptor))
        output.alwaysCopiesSampleData=false;guard reader.canAdd(output) else {throw AutomaticSelectionEngine.error("This video cannot supply decoded frames for matting.")};reader.add(output)
        reader.timeRange=CMTimeRange(start:CMTime(seconds:range.lowerBound,preferredTimescale:60000),end:CMTime(seconds:range.upperBound,preferredTimescale:60000))
        guard reader.startReading() else {throw AutomaticSelectionEngine.error("Video matte reader could not start: "+(reader.error?.localizedDescription ?? "unknown read error"))};defer {reader.cancelReading()}
        #if DEBUG
        VerificationProgress.record("People matte reader started")
        #endif
        try DeliveryStorage.require(planned:48_000_000)
        let request=VNGeneratePersonSegmentationRequest();request.qualityLevel = .accurate;request.outputPixelFormat=kCVPixelFormatType_OneComponent32Float;request.preferBackgroundProcessing=true
        let handler=VNSequenceRequestHandler(),context=ImageEngine.context(),gray=CGColorSpace(name:CGColorSpace.linearGray)!
        var full=recipe;full.reset(.crop)
        var frames=[TemporalMatte.Frame](),bytes=0,personFound=false
        while let sample=output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard ProcessInfo.processInfo.thermalState.rawValue<ProcessInfo.ThermalState.serious.rawValue else {throw AutomaticSelectionEngine.error("Processing paused for cooling. The previous mask is unchanged; try again after the phone cools.")}
            let time=CMSampleBufferGetPresentationTimeStamp(sample).seconds
            if time<range.lowerBound || time>=range.upperBound {continue}
            guard frames.count<360 else {throw AutomaticSelectionEngine.error("This clip has more than 360 source frames. Shorten the kept clip.")}
            let frame=try autoreleasepool {() throws ->TemporalMatte.Frame in
                guard let buffer=CMSampleBufferGetImageBuffer(sample) else {throw AutomaticSelectionEngine.error("Video matte frame did not contain image data.")}
                #if DEBUG
                if frames.isEmpty {VerificationProgress.record("People matte first frame")}
                #endif
                let cg=try MaskTracker.frame(buffer,descriptor:descriptor,recipe:full,context:context)
                try handler.perform([request],on:cg,orientation:.up)
                try Task.checkCancellation()
                guard let mask=request.results?.first?.pixelBuffer else {throw StudioError.render}
                let raw=CIImage(cvPixelBuffer:mask,options:[.colorSpace:NSNull()])
                let scale=min(1,1536/max(raw.extent.width,raw.extent.height))
                var image=raw.transformed(by:.init(scaleX:scale,y:scale))
                image=image.transformed(by:.init(translationX:-image.extent.minX,y:-image.extent.minY)).cropped(to:CGRect(x:0,y:0,width:max(1,floor(image.extent.width)),height:max(1,floor(image.extent.height))))
                if !personFound {personFound=AutomaticSelectionEngine.hasCoverage(image)}
                guard let png=context.pngRepresentation(of:image,format:.L8,colorSpace:gray,options:[:]) else {throw StudioError.render}
                return .init(id:UUID(),time:time,png:png,width:Int(image.extent.width),height:Int(image.extent.height))
            }
            bytes+=frame.png.count;guard bytes<=16_777_216 else {throw AutomaticSelectionEngine.error("This matte exceeds the 16 MB budget. Shorten the kept clip; your previous selection is unchanged.")}
            frames.append(frame);await progress((time-range.lowerBound)/(range.upperBound-range.lowerBound))
            #if DEBUG
            if frames.count%30==0 {VerificationProgress.record("People matte processed \(frames.count) frames, \(bytes) bytes")}
            #endif
            try await Task.sleep(for:.milliseconds(ProcessInfo.processInfo.thermalState == .fair ? 50:10))
        }
        guard reader.status == .completed,personFound,let first=frames.first else {throw AutomaticSelectionEngine.error("No clear person was found, or reading was interrupted. Existing edits are unchanged.")}
        #if DEBUG
        VerificationProgress.record("People matte complete: count=\(frames.count), first=\(frames.first!.time), last=\(frames.last!.time), dims=\(frames.first!.width)x\(frames.first!.height), bytes=\(bytes), ordered=\(zip(frames,frames.dropFirst()).allSatisfy {$0.time<$1.time})")
        #endif
        try Task.checkCancellation()
        let temporal=try TemporalMatte(start:range.lowerBound,end:range.upperBound,sourceDuration:descriptor.duration,sourceWidth:descriptor.width,sourceHeight:descriptor.height,input:recipe.input,frames:frames)
        return AutomaticMask(id:first.id,png:first.png,width:first.width,height:first.height,framing:MaskMotion.signature(recipe),videoStart:range.lowerBound,temporal:temporal)
    }
}
