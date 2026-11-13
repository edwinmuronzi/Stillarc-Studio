import AVFoundation
import CoreImage
import Vision

struct TrackingSeed:Sendable {
    var x = 0.5
    var y = 0.5
    var width = 0.25
    var height = 0.25
    var rect:CGRect { CGRect(x:min(1-width,max(0,x-width/2)),y:min(1-height,max(0,1-y-height/2)),width:width,height:height) }
}
enum TrackingQuality:String,CaseIterable,Identifiable {case detailed="Detailed",efficient="Efficient";var id:String {rawValue}}
enum TrackingGeometry:String,CaseIterable,Identifiable,Sendable {
    case position="Position",size="Position + size",rectangle="Rectangle pose"
    var id:String {rawValue}
}
enum MaskTracker {
    static func settings(_ descriptor:VideoDescriptor) -> [String:Any] {
        let swapped = abs(descriptor.affine.a)<0.5 && abs(descriptor.affine.d)<0.5
        let w = Double(swapped ? descriptor.height : descriptor.width),h = Double(swapped ? descriptor.width : descriptor.height),scale = min(1,640/max(w,h))
        return [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:max(2,Int(w*scale)/2*2),kCVPixelBufferHeightKey as String:max(2,Int(h*scale)/2*2),kCVPixelBufferIOSurfacePropertiesKey as String:[:]]
    }
    static func failure(_ message:String) -> NSError { NSError(domain:"MaskTracking",code:2,userInfo:[NSLocalizedDescriptionKey:message]) }
    static func frame(_ buffer:CVPixelBuffer,descriptor:VideoDescriptor,recipe:Recipe,context:CIContext) throws -> CGImage {
        let pair = VideoEngine.images(buffer,descriptor:descriptor,maxDimension:800)
        var input = recipe.input;input.softHighlights = true
        var decoded = LogConversion.apply(input.profile == .standard ? pair.managed : pair.signal,input:input)
        if descriptor.hdrTransfer != nil { decoded = decoded.applyingFilter("CIExposureAdjust",parameters:[kCIInputEVKey:-2]) }
        var image = PhotoFraming.apply(decoded,recipe:recipe)
        let scale = min(1,640/max(image.extent.width,image.extent.height));image = image.transformed(by:.init(scaleX:scale,y:scale))
        image = image.transformed(by:.init(translationX:-image.extent.minX,y:-image.extent.minY))
        guard let cg = context.createCGImage(image,from:image.extent,format:.RGBA8,colorSpace:ImageEngine.output) else { throw StudioError.render };return cg
    }
    static func suggestedSeed(_ mask:AutomaticMask)->TrackingSeed? {
        guard let image=AutomaticMaskBitmap.image(mask,extent:CGRect(x:0,y:0,width:64,height:64),preview:false) else {return nil}
        var pixels=[UInt8](repeating:0,count:4096)
        ImageEngine.context().render(image,toBitmap:&pixels,rowBytes:64,bounds:CGRect(x:0,y:0,width:64,height:64),format:.L8,colorSpace:CGColorSpace(name:CGColorSpace.linearGray))
        var minX=64,minY=64,maxX = -1,maxY = -1
        for y in 0..<64 {for x in 0..<64 where pixels[y*64+x]>160 {minX=min(minX,x);maxX=max(maxX,x);minY=min(minY,y);maxY=max(maxY,y)}}
        guard maxX>=minX,maxY>=minY else {return nil}
        return TrackingSeed(x:Double(minX+maxX+1)/128,y:Double(minY+maxY+1)/128,width:min(0.7,max(0.08,Double(maxX-minX+1)/64)),height:min(0.7,max(0.08,Double(maxY-minY+1)/64)))
    }
    static func seedFrame(url:URL,descriptor:VideoDescriptor,recipe:Recipe) async throws -> CGImage {
        let asset = AVURLAsset(url:url),reader = try AVAssetReader(asset:asset)
        guard let track = try await asset.loadTracks(withMediaType:.video).first else { throw StudioError.unreadable }
        let output = AVAssetReaderTrackOutput(track:track,outputSettings:settings(descriptor));guard reader.canAdd(output) else { throw StudioError.unreadable };reader.add(output)
        let range = recipe.video.range(duration:descriptor.duration)
        reader.timeRange = CMTimeRange(start:CMTime(seconds:range.lowerBound,preferredTimescale:60000),end:CMTime(seconds:range.upperBound,preferredTimescale:60000))
        guard reader.startReading() else { throw StudioError.unreadable };defer { reader.cancelReading() }
        guard let sample = output.copyNextSampleBuffer(),let buffer = CMSampleBufferGetImageBuffer(sample) else { throw StudioError.unreadable }
        try Task.checkCancellation();return try frame(buffer,descriptor:descriptor,recipe:recipe,context:ImageEngine.context())
    }
    static func analyze(url:URL,descriptor:VideoDescriptor,recipe:Recipe,seed:TrackingSeed,quality:TrackingQuality = .detailed,geometry:TrackingGeometry = .position,recoverUsablePath:Bool = false,progress:@escaping @Sendable (Double) async -> Void) async throws -> MaskMotion {
        try Task.checkCancellation();try LogConversion.prepare()
        guard seed.x.isFinite,seed.y.isFinite,seed.width.isFinite,seed.height.isFinite,(0...1).contains(seed.x),(0...1).contains(seed.y),(0.08...0.7).contains(seed.width),(0.08...0.7).contains(seed.height) else { throw failure("Choose a valid target box inside the picture.") }
        let range = recipe.video.range(duration:descriptor.duration)
        guard range.upperBound-range.lowerBound<=120 else { throw failure("Trim the kept clip to two minutes or less before tracking.") }
        let asset = AVURLAsset(url:url)
        guard let track = try await asset.loadTracks(withMediaType:.video).first else { throw StudioError.unreadable }
        let reader = try AVAssetReader(asset:asset),output = AVAssetReaderTrackOutput(track:track,outputSettings:settings(descriptor))
        output.alwaysCopiesSampleData = false;guard reader.canAdd(output) else { throw StudioError.unreadable };reader.add(output)
        reader.timeRange = CMTimeRange(start:CMTime(seconds:range.lowerBound,preferredTimescale:60000),end:CMTime(seconds:range.upperBound,preferredTimescale:60000))
        guard reader.startReading() else { throw StudioError.unreadable };defer { reader.cancelReading() }
        let context = ImageEngine.context(),handler = VNSequenceRequestHandler(),initial = seed.rect
        var request:VNTrackingRequest = VNTrackObjectRequest(detectedObjectObservation:VNDetectedObjectObservation(boundingBox:initial));request.trackingLevel = quality == .detailed ? .accurate:.fast
        var points = [MaskMotionPoint](),lastTime = -Double.infinity
        var anchor:CGPoint?
        var anchorSize:Double?,anchorAngle:Double?,lastAngle=0.0
        var recoveryTime:Double?
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard ProcessInfo.processInfo.thermalState.rawValue<ProcessInfo.ThermalState.serious.rawValue else { throw failure("The phone needs to cool before tracking. Your previous edits are unchanged.") }
            let time = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            if time<range.lowerBound || time>=range.upperBound || time-lastTime<1.0/15-0.001 { continue }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--verify-tracking-only") && points.count%15 == 0 { VerificationProgress.record("Tracking frame \(points.count) before Vision") }
            #endif
            do {try autoreleasepool {
                guard let buffer = CMSampleBufferGetImageBuffer(sample) else { throw StudioError.unreadable }
                let cg = try frame(buffer,descriptor:descriptor,recipe:recipe,context:context)
                if points.isEmpty,geometry == .rectangle {
                    let detect=VNDetectRectanglesRequest();detect.maximumObservations=12;detect.minimumConfidence=0.5;detect.minimumAspectRatio=0.1;detect.minimumSize=0.05
                    try VNImageRequestHandler(cgImage:cg,orientation:.up).perform([detect])
                    func overlap(_ box:CGRect)->Double {let i=box.intersection(initial);return i.isNull ? 0:i.width*i.height/max(0.000001,box.width*box.height+initial.width*initial.height-i.width*i.height)}
                    guard let target=detect.results?.max(by:{overlap($0.boundingBox)<overlap($1.boundingBox)}),overlap(target.boundingBox)>0.1 else {throw failure("Place the target around a visible rectangular sign, screen or card for rotation tracking.")}
                    request=VNTrackRectangleRequest(rectangleObservation:target);request.trackingLevel=quality == .detailed ? .accurate:.fast
                }
                try handler.perform([request],on:cg,orientation:.up)
                guard let observation = request.results?.first as? VNDetectedObjectObservation,observation.confidence>=0.35 else { throw failure("Tracking lost the target. Choose a smaller, textured region that stays visible and try again. The previous track is unchanged.") }
                let box = observation.boundingBox
                guard box.minX>=0,box.maxX<=1,box.minY>=0,box.maxY<=1 else { throw failure("The target left the picture. Trim the clip or choose another region.") }
                if anchor == nil { anchor = CGPoint(x:box.midX,y:box.midY) }
                let dx = box.midX-anchor!.x,dy = anchor!.y-box.midY
                if let previous = points.last,abs(dx-previous.x)+abs(dy-previous.y)>0.2 { throw failure("The target moved too far between tracked frames. Try a shorter clip or a steadier target.") }
                guard abs(dx)<=1,abs(dy)<=1 else { throw StudioError.render }
                var size=sqrt(box.width*box.height),angle=0.0
                if geometry == .rectangle {
                    guard let rectangle=observation as? VNRectangleObservation else {throw failure("The rectangular target could not be followed.")}
                    let w=Double(cg.width),h=Double(cg.height)
                    let vx=(rectangle.topRight.x-rectangle.topLeft.x)*w,vy=(rectangle.topRight.y-rectangle.topLeft.y)*h
                    let ux=(rectangle.bottomLeft.x-rectangle.topLeft.x)*w,uy=(rectangle.bottomLeft.y-rectangle.topLeft.y)*h
                    size=sqrt(hypot(vx,vy)*hypot(ux,uy))
                    angle = -atan2(vy,vx)*180 / .pi
                    if let anchorAngle {angle-=anchorAngle;while angle-lastAngle>180 {angle-=360};while angle-lastAngle < -180 {angle+=360}}
                    else {anchorAngle=angle;angle=0}
                }
                if anchorSize == nil {anchorSize=size}
                let scale=geometry == .position ? 1:size/max(0.000001,anchorSize!)
                guard scale.isFinite,(0.25...4).contains(scale),abs(angle)<=3600 else {throw failure("The target changed too much. Use a shorter clip or a steadier region.")}
                if !points.isEmpty,geometry == .rectangle,abs(angle-lastAngle)>45 {throw failure("Rotation tracking became unreliable. The previous track is unchanged.")}
                points.append(MaskMotionPoint(time:time,x:dx,y:dy,scale:scale==1 ? nil:scale,rotation:angle==0 ? nil:angle));lastTime = time;lastAngle=angle
                request.inputObservation = observation
            }} catch {
                // Only a lost/unreliable target can produce a reviewable partial path. Reader,
                // decoding, cancellation and thermal failures still discard the attempted update.
                let e=error as NSError
                guard recoverUsablePath,e.domain=="MaskTracking",points.count>=2,let last=points.last else {throw error}
                recoveryTime=last.time
                break
            }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--verify-tracking-only") && points.count%15 == 1 { VerificationProgress.record("Tracking frame \(points.count) completed") }
            #endif
            await progress((time-range.lowerBound)/(range.upperBound-range.lowerBound))
            try await Task.sleep(for:.milliseconds(ProcessInfo.processInfo.thermalState == .fair ? 20 : 3))
        }
        try Task.checkCancellation()
        guard (reader.status == .completed || recoveryTime != nil),points.count>=2 else { throw failure("The kept clip is too short to track.") }
        var motion = MaskMotion(framing:MaskMotion.signature(recipe),start:range.lowerBound,end:range.upperBound,points:points,pivotX:anchor?.x ?? initial.midX,pivotY:1-(anchor?.y ?? initial.midY),sourceWidth:Double(descriptor.width),sourceHeight:Double(descriptor.height))
        motion.recoveryTime=recoveryTime
        guard motion.isValid else { throw StudioError.render };return motion
    }
}
